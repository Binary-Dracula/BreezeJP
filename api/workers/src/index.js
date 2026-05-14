// Workers 主入口
// 路由：
//   GET  /api/v1/articles              - 新闻列表（增量同步）
//   GET  /api/v1/articles/:id          - 新闻详情（含分词）
//   GET  /api/v1/audio/:id             - 文章音频代理
//   GET  /api/v1/audio/words/:id       - 词汇音频代理
//   GET  /api/v1/books                 - 词书列表
//   GET  /api/v1/reference             - 参考内容
//   POST /api/v1/issues                - 问题上报（需认证）
//   GET  /api/v1/health                - 健康检查（无需认证）
//   OPTIONS *                          - CORS 预检
import { verifyAuth, verifyOptionalAuth, unauthorizedResponse } from './middleware/auth';
import { corsHeaders, handleOptions } from './middleware/cors';
import { handleArticleList, handleArticleDetail } from './routes/articles';
import { handleAudio, handleWordAudio } from './routes/audio';
import { handleToggleExampleFavorite, handleToggleWordFavorite } from './routes/favorites';
import { handleGrammarDetail, handleGrammarList, handleGrammarStates } from './routes/grammar';
import { handleHomeSummary } from './routes/home';
import { handleKanaStates, handleUpsertKanaStates } from './routes/kana';
import { handleReferenceContent } from './routes/reference';
import { handleAbandonReviewSession, handleCompleteReviewSession, handleCreateReviewSession, handleGrammarBook, handleUpsertWordStates, handleWordBook, handleWordExampleFavorites } from './routes/study';
import { handleBookList, handleCompleteLearnSession, handleCreateLearnSession, handleNextWords, handleWordDetail } from './routes/vocab';
import { handleCreateIssue } from './routes/issues';
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;
        const method = request.method;
        // ---- OPTIONS 预检 ----
        if (method === 'OPTIONS') {
            return handleOptions(request);
        }
        // ---- 健康检查（无需认证）----
        if (method === 'GET' && path === '/api/v1/health') {
            return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
                headers: {
                    'Content-Type': 'application/json',
                    ...corsHeaders(request),
                },
            });
        }
        // ---- POST /api/v1/issues（需 JWT 认证）----
        if (method === 'POST' && path === '/api/v1/issues') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleCreateIssue(request, env, auth);
        }
        if (method === 'POST' && path === '/api/v1/learn/sessions') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleCreateLearnSession(request, env, auth);
        }
        const learnSessionCompleteMatch = path.match(/^\/api\/v1\/learn\/sessions\/([^/]+)\/complete$/);
        if (method === 'POST' && learnSessionCompleteMatch) {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleCompleteLearnSession(request, env, auth, learnSessionCompleteMatch[1]);
        }
        if (method === 'POST' && path === '/api/v1/review/sessions') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleCreateReviewSession(request, env, auth);
        }
        const reviewSessionCompleteMatch = path.match(/^\/api\/v1\/review\/sessions\/([^/]+)\/complete$/);
        if (method === 'POST' && reviewSessionCompleteMatch) {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleCompleteReviewSession(request, env, auth, reviewSessionCompleteMatch[1]);
        }
        const reviewSessionAbandonMatch = path.match(/^\/api\/v1\/review\/sessions\/([^/]+)\/abandon$/);
        if (method === 'POST' && reviewSessionAbandonMatch) {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleAbandonReviewSession(request, env, auth, reviewSessionAbandonMatch[1]);
        }
        if (method === 'POST' && path === '/api/v1/favorites/words/toggle') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleToggleWordFavorite(request, env, auth);
        }
        if (method === 'POST' && path === '/api/v1/favorites/examples/toggle') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleToggleExampleFavorite(request, env, auth);
        }
        if (method === 'POST' && path === '/api/v1/grammar/states') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleGrammarStates(request, env, auth);
        }
        if (method === 'POST' && path === '/api/v1/kana/states') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleUpsertKanaStates(request, env, auth);
        }
        if (method === 'POST' && path === '/api/v1/word/states') {
            const auth = await verifyAuth(request, env);
            if (!auth) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleUpsertWordStates(request, env, auth);
        }
        // ---- 仅允许 GET/HEAD 方法（其余路由）----
        if (method !== 'GET' && method !== 'HEAD') {
            return new Response(JSON.stringify({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Only GET and HEAD are supported' } }), { status: 405, headers: { 'Content-Type': 'application/json' } });
        }
        // ---- 公开只读路由（游客可访问，无需认证）----
        // GET /api/v1/books
        if (path === '/api/v1/books') {
            return handleBookList(request, env);
        }
        if (path === '/api/v1/reference') {
            return handleReferenceContent(request);
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
        const wordDetailMatch = path.match(/^\/api\/v1\/words\/([^/]+)$/);
        if (wordDetailMatch) {
            const optionalAuth = await verifyOptionalAuth(request, env);
            if (optionalAuth.invalid) {
                return unauthorizedResponse('Invalid or expired token. Please re-login.');
            }
            return handleWordDetail(request, env, wordDetailMatch[1], optionalAuth.auth);
        }
        // ---- JWT 认证（其余 /api/v1/* 路由都需要）----
        const auth = await verifyAuth(request, env);
        if (!auth) {
            return unauthorizedResponse('Invalid or expired token. Please re-login.');
        }
        // ---- 路由匹配 ----
        if (path === '/api/v1/me/word-book') {
            return handleWordBook(request, env, auth);
        }
        if (path === '/api/v1/me/example-favorites') {
            return handleWordExampleFavorites(request, env, auth);
        }
        if (path === '/api/v1/me/grammar-book') {
            return handleGrammarBook(request, env, auth);
        }
        if (path === '/api/v1/me/home-summary') {
            return handleHomeSummary(request, env, auth);
        }
        if (path === '/api/v1/me/kana-states') {
            return handleKanaStates(request, env, auth);
        }
        if (path === '/api/v1/grammars') {
            return handleGrammarList(request, env, auth);
        }
        const grammarDetailMatch = path.match(/^\/api\/v1\/grammars\/(\d+)$/);
        if (grammarDetailMatch) {
            return handleGrammarDetail(request, env, auth, Number.parseInt(grammarDetailMatch[1], 10));
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
        return new Response(JSON.stringify({ error: { code: 'NOT_FOUND', message: `Route '${path}' not found` } }), {
            status: 404,
            headers: {
                'Content-Type': 'application/json',
                ...corsHeaders(request),
            },
        });
    },
};
