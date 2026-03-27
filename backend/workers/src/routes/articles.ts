// 新闻列表和详情路由
// GET /api/v1/articles         - 获取新闻列表（支持增量同步）
// GET /api/v1/articles/:id     - 获取新闻详情（含分词）

import { Env, ArticleListItem, ArticleDetail, PaginationMeta } from '../types';
import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';

// 创建 Supabase REST 请求的通用函数（使用 fetch 直接调用，无需 SDK）
async function supabaseFetch(
  env: Env,
  path: string,
  params?: Record<string, string>
): Promise<Response> {
  const url = new URL(`${env.SUPABASE_URL}/rest/v1${path}`);
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, v);
    }
  }
  return fetch(url.toString(), {
    headers: {
      'apikey': env.SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'count=exact',         // 获取总数
    },
  });
}

/**
 * GET /api/v1/articles
 * 查询参数：
 *   since  - ISO8601 时间字符串，只返回该时间之后更新的文章（增量同步）
 *   limit  - 每页数量，默认 50，最大 200
 *   cursor - 分页游标（上一页最后一篇文章的 published_at）
 */
export async function handleArticleList(
  request: Request,
  env: Env,
  _auth: AuthPayload
): Promise<Response> {
  const url = new URL(request.url);
  const since = url.searchParams.get('since');
  const limitRaw = parseInt(url.searchParams.get('limit') ?? '50', 10);
  const limit = Math.min(Math.max(limitRaw, 1), 200);
  const cursor = url.searchParams.get('cursor'); // ISO8601 时间

  const serverTime = new Date().toISOString();

  // ---- 尝试 KV 缓存（仅全量请求且无 cursor 时缓存）----
  const cacheKey = since ? null : `articles_list_${limit}`;
  if (cacheKey) {
    const cached = await env.CACHE.get(cacheKey, 'json') as { data: ArticleListItem[]; meta: PaginationMeta } | null;
    if (cached) {
      // 更新 server_time 后返回缓存
      cached.meta.server_time = serverTime;
      return jsonResponse({ data: cached.data, meta: cached.meta }, {
        'Cache-Control': 'public, max-age=300',
        ...corsHeaders(request),
      });
    }
  }

  // ---- 构建 Supabase 查询参数 ----
  const params: Record<string, string> = {
    select: 'id,title,clean_title,published_at,audio_url,duration_ms,sentence_count,is_archived',
    order: 'published_at.desc',
    limit: String(limit),
  };

  // 增量：只返回 updated_at > since 的文章
  if (since) {
    params['updated_at'] = `gt.${since}`;
  }

  // 分页游标：只返回 published_at < cursor 的文章
  if (cursor) {
    params['published_at'] = `lt.${cursor}`;
  }

  const resp = await supabaseFetch(env, '/articles', params);

  if (!resp.ok) {
    console.error('Supabase articles error:', await resp.text());
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch articles');
  }

  const articles = (await resp.json()) as ArticleListItem[];
  const totalHeader = resp.headers.get('Content-Range'); // e.g. "0-49/100"
  const total = totalHeader ? parseInt(totalHeader.split('/')[1], 10) : articles.length;

  const hasMore = articles.length === limit;
  const nextCursor = hasMore ? articles[articles.length - 1].published_at : null;

  const meta: PaginationMeta = {
    total,
    has_more: hasMore,
    cursor: nextCursor,
    server_time: serverTime,
  };

  // ---- 写入 KV 缓存（仅全量请求）----
  if (cacheKey && articles.length > 0) {
    const ttl = parseInt(env.CACHE_TTL_ARTICLES, 10);
    await env.CACHE.put(cacheKey, JSON.stringify({ data: articles, meta }), {
      expirationTtl: ttl,
    });
  }

  return jsonResponse(
    { data: articles, meta },
    {
      'Cache-Control': since ? 'no-store' : 'public, max-age=300',
      ...corsHeaders(request),
    }
  );
}

/**
 * GET /api/v1/articles/:id
 * 返回新闻详情（含完整 items 分词数据）
 */
export async function handleArticleDetail(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  id: string
): Promise<Response> {
  // ---- KV 缓存 ----
  const cacheKey = `article_detail_${id}`;
  const cached = await env.CACHE.get(cacheKey, 'json') as ArticleDetail | null;
  if (cached) {
    return jsonResponse(
      { data: cached },
      {
        'Cache-Control': `public, max-age=${env.CACHE_TTL_DETAIL}`,
        ...corsHeaders(request),
      }
    );
  }

  // ---- 查询 articles 元数据 ----
  const metaResp = await supabaseFetch(env, '/articles', {
    select: 'id,title,clean_title,published_at,audio_url,duration_ms,sentence_count,is_archived',
    id: `eq.${id}`,
    limit: '1',
  });

  if (!metaResp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch article metadata');
  }

  const metaList = (await metaResp.json()) as ArticleListItem[];
  if (!metaList.length) {
    return errorResponse(404, 'NOT_FOUND', `Article '${id}' not found`);
  }
  const meta = metaList[0];

  // ---- 查询 article_details（items 分词数据）----
  const detailResp = await supabaseFetch(env, '/article_details', {
    select: 'items',
    article_id: `eq.${id}`,
    limit: '1',
  });

  if (!detailResp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch article details');
  }

  const detailList = (await detailResp.json()) as { items: unknown[] }[];
  const items = detailList.length ? detailList[0].items : [];

  const article: ArticleDetail = { ...meta, items: items as ArticleDetail['items'] };

  // ---- 写入 KV 缓存 ----
  const ttl = parseInt(env.CACHE_TTL_DETAIL, 10);
  await env.CACHE.put(cacheKey, JSON.stringify(article), { expirationTtl: ttl });

  return jsonResponse(
    { data: article },
    {
      'Cache-Control': `public, max-age=${env.CACHE_TTL_DETAIL}`,
      ...corsHeaders(request),
    }
  );
}

// ---- 工具函数 ----

function jsonResponse(body: unknown, extraHeaders?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
  });
}

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ error: { code, message } }),
    {
      status,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}
