/**
 * 通用的 Supabase REST API fetch 封装
 */
export async function supabaseFetch(env, path, params, options) {
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
 * 调用 Supabase Postgres RPC 函数。
 */
export async function supabaseRpc(env, fn, payload, options) {
    return fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
        method: 'POST',
        headers: {
            'apikey': env.SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'application/json',
            ...options?.headers,
        },
        body: JSON.stringify(payload),
    });
}
/**
 * 统一的 JSON 响应封装
 */
export function jsonResponse(body, extraHeaders) {
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
export function errorResponse(status, code, message) {
    return new Response(JSON.stringify({ error: { code, message } }), {
        status,
        headers: { 'Content-Type': 'application/json' },
    });
}
