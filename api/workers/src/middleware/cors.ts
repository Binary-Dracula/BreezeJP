// CORS 中间件
// 允许来自 App 的跨域请求（主要针对 Web 版本）

const ALLOWED_ORIGINS = [
  'https://binary-dracula.com',
  'https://admin.binary-dracula.com',
  'http://localhost:3000',  // 本地开发
  'http://localhost:5173',  // Vite 开发服务器
  'http://localhost:8787',  // wrangler dev
];

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') ?? '';
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
  };
}

export function handleOptions(request: Request): Response {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(request),
  });
}
