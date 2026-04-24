// Workers 主入口
// 路由：
//   GET  /api/v1/articles         - 新闻列表（增量同步）
//   GET  /api/v1/articles/:id     - 新闻详情（含分词）
//   GET  /api/v1/audio/:id        - 文章音频代理
//   GET  /api/v1/audio/words/:id  - 词汇音频代理
//   POST /api/v1/issues           - 问题上报（需认证）
//   GET  /api/v1/health           - 健康检查（无需认证）
//   OPTIONS *                     - CORS 预检

import { Env } from './types';
import { verifyAuth, unauthorizedResponse } from './middleware/auth';
import { corsHeaders, handleOptions } from './middleware/cors';
import { handleArticleList, handleArticleDetail } from './routes/articles';
import { handleAudio, handleWordAudio } from './routes/audio';
import { handleBookList, handleBookSync, handleNextWords, handleWordSync } from './routes/vocab';
import { handleCreateIssue } from './routes/issues';

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

    // ---- POST /api/v1/issues（需 JWT 认证）----
    if (method === 'POST' && path === '/api/v1/issues') {
      const auth = await verifyAuth(request, env);
      if (!auth) {
        return unauthorizedResponse('Invalid or expired token. Please re-login.');
      }
      return handleCreateIssue(request, env, auth);
    }

    // ---- 仅允许 GET/HEAD 方法（其余路由）----
    if (method !== 'GET' && method !== 'HEAD') {
      return new Response(
        JSON.stringify({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Only GET and HEAD are supported' } }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // ---- 公开只读路由（游客可访问，无需认证）----

    // GET /api/v1/books
    if (path === '/api/v1/books') {
      return handleBookList(request, env);
    }

    // GET /api/v1/books/sync?since=<ISO>
    if (path === '/api/v1/books/sync') {
      return handleBookSync(request, env);
    }

    // GET /api/v1/books/:id/next-words?after_sort=<N>&limit=<M>
    const nextWordsMatch = path.match(/^\/api\/v1\/books\/([^/]+)\/next-words$/);
    if (nextWordsMatch) {
      return handleNextWords(request, env, nextWordsMatch[1]);
    }

    // GET /api/v1/audio/words/:id
    const wordAudioMatch = path.match(/^\/api\/v1\/audio\/words\/([^/]+)$/);
    if (wordAudioMatch) {
      return handleWordAudio(request, env, wordAudioMatch[1]);
    }

    // ---- JWT 认证（其余 /api/v1/* 路由都需要）----
    const auth = await verifyAuth(request, env);
    if (!auth) {
      return unauthorizedResponse('Invalid or expired token. Please re-login.');
    }

    // ---- 路由匹配 ----

    // GET /api/v1/words/sync?since=<ISO>
    if (path === '/api/v1/words/sync') {
      return handleWordSync(request, env, auth);
    }

    // GET /api/v1/articles
    if (path === '/api/v1/articles') {
      return handleArticleList(request, env, auth);
    }

    // GET /api/v1/articles/:id
    const articleDetailMatch = path.match(/^\/api\/v1\/articles\/([^/]+)$/);
    if (articleDetailMatch) {
      return handleArticleDetail(request, env, auth, articleDetailMatch[1]);
    }

    // ---- 音频代理（兼容 1.0 与 2.0） ----

    // GET /api/v1/audio/:id (Strict Legacy fallback)
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
