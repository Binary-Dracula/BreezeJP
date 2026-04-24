import { Env } from '../types';

/**
 * 通用的 Supabase REST API fetch 封装
 */
export async function supabaseFetch(
  env: Env,
  path: string,
  params?: Record<string, string>,
  options?: {
    method?: string;
    body?: unknown;
    headers?: Record<string, string>;
  }
): Promise<Response> {
  const url = new URL(`${env.SUPABASE_URL}/rest/v1${path}`);
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, v);
    }
  }
  return fetch(url.toString(), {
    method: options?.method ?? 'GET',
    headers: {
      'apikey': env.SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'count=exact',
      ...options?.headers,
    },
    body: options?.body ? JSON.stringify(options.body) : undefined,
  });
}

/**
 * 统一的 JSON 响应封装
 */
export function jsonResponse(body: unknown, extraHeaders?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
  });
}

/**
 * 统一的错误响应封装
 */
export function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ error: { code, message } }),
    {
      status,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}
