// Workers 主入口
// 路由：
//   GET  /api/v1/articles         - 新闻列表（增量同步）
//   GET  /api/v1/articles/:id     - 新闻详情（含分词）
//   GET  /api/v1/audio/:id        - 音频代理
//   GET  /api/v1/health           - 健康检查（无需认证）
//   OPTIONS *                     - CORS 预检

import { Env } from './types';
import { verifyAuth, unauthorizedResponse } from './middleware/auth';
import { corsHeaders, handleOptions } from './middleware/cors';
import { handleArticleList, handleArticleDetail } from './routes/articles';
import { handleAudio } from './routes/audio';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // ---- OPTIONS 预检 ----
    if (method === 'OPTIONS') {
      return handleOptions(request);
    }

    // ---- 健康检查（无需认证）----
    if (method === 'GET' && path === '/api/v1/health') {
      return new Response(
        JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }),
        {
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders(request),
          },
        }
      );
    }

    // ---- 仅允许 GET/HEAD 方法 ----
    if (method !== 'GET' && method !== 'HEAD') {
      return new Response(
        JSON.stringify({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Only GET and HEAD are supported' } }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // ---- JWT 认证（所有 /api/v1/* 路由都需要）----
    const auth = await verifyAuth(request, env);
    if (!auth) {
      return unauthorizedResponse('Invalid or expired token. Please re-login.');
    }

    // ---- 路由匹配 ----

    // GET /api/v1/articles
    if (path === '/api/v1/articles') {
      return handleArticleList(request, env, auth);
    }

    // GET /api/v1/articles/:id
    const articleDetailMatch = path.match(/^\/api\/v1\/articles\/([^/]+)$/);
    if (articleDetailMatch) {
      return handleArticleDetail(request, env, auth, articleDetailMatch[1]);
    }

    // GET /api/v1/audio/:id
    const audioMatch = path.match(/^\/api\/v1\/audio\/([^/]+)$/);
    if (audioMatch) {
      return handleAudio(request, env, auth, audioMatch[1]);
    }

    // ---- 404 ----
    return new Response(
      JSON.stringify({ error: { code: 'NOT_FOUND', message: `Route '${path}' not found` } }),
      {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      }
    );
  },
};
