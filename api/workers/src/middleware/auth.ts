// JWT 验证中间件
// Supabase 新版使用 ES256 (ECDSA P-256) 签名 JWT
// 从 Supabase JWKS 端点获取公钥并缓存，验证签名

import { Env } from '../types';

export interface AuthPayload {
  sub: string;          // user_id (UUID)
  role: string;         // "authenticated"
  is_anonymous: boolean;
  exp: number;
}

export interface OptionalAuthResult {
  auth: AuthPayload | null;
  invalid: boolean;
}

// 缓存 JWKS 公钥（Worker 生命周期内有效，约 30s~5min）
let cachedKeys: Map<string, CryptoKey> = new Map();
let cacheExpiry = 0;

/**
 * 获取 Supabase JWKS 公钥
 * 从 {SUPABASE_URL}/.well-known/jwks.json 获取
 * 缓存 1 小时避免重复请求
 */
async function getJWKS(env: Env): Promise<Map<string, CryptoKey>> {
  const now = Date.now();
  if (cachedKeys.size > 0 && now < cacheExpiry) {
    return cachedKeys;
  }

  const url = `${env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`;
  const resp = await fetch(url);
  if (!resp.ok) {
    throw new Error(`Failed to fetch JWKS: ${resp.status}`);
  }

  const jwks = (await resp.json()) as { keys: JsonWebKey[] };
  const keys = new Map<string, CryptoKey>();

  for (const jwk of jwks.keys) {
    if (jwk.kty === 'EC' && jwk.crv === 'P-256') {
      const kid = (jwk as unknown as Record<string, string>).kid ?? 'default';
      const cryptoKey = await crypto.subtle.importKey(
        'jwk',
        jwk,
        { name: 'ECDSA', namedCurve: 'P-256' },
        false,
        ['verify']
      );
      keys.set(kid, cryptoKey);
    }
  }

  cachedKeys = keys;
  cacheExpiry = now + 3600_000; // 缓存 1 小时
  return keys;
}

/**
 * 从请求头提取并验证 JWT
 * 验证通过返回 payload，否则返回 null
 */
export async function verifyAuth(
  request: Request,
  env: Env
): Promise<AuthPayload | null> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7);

  try {
    // 分割 JWT
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [headerB64, payloadB64, signatureB64] = parts;

    // 解析 header 获取 kid
    const headerJson = atob(headerB64.replace(/-/g, '+').replace(/_/g, '/'));
    const header = JSON.parse(headerJson) as { alg: string; kid?: string };

    // 获取公钥
    const keys = await getJWKS(env);
    const kid = header.kid ?? 'default';
    const cryptoKey = keys.get(kid);

    if (!cryptoKey) {
      console.error(`No key found for kid: ${kid}`);
      return null;
    }

    // 验证 ES256 签名
    const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = base64UrlToArrayBuffer(signatureB64);

    const valid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      cryptoKey,
      signature,
      signedData
    );

    if (!valid) return null;

    // 解码 payload
    const payloadJson = atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/'));
    const payload = JSON.parse(payloadJson);

    // 检查过期
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return {
      sub: payload.sub,
      role: payload.role ?? 'authenticated',
      is_anonymous: payload.is_anonymous ?? false,
      exp: payload.exp,
    };
  } catch (e) {
    console.error('JWT verification error:', e);
    return null;
  }
}

export async function verifyOptionalAuth(
  request: Request,
  env: Env,
): Promise<OptionalAuthResult> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return { auth: null, invalid: false };
  }

  const auth = await verifyAuth(request, env);
  return {
    auth,
    invalid: auth == null,
  };
}

/**
 * Base64Url 字符串 → ArrayBuffer
 */
function base64UrlToArrayBuffer(str: string): ArrayBuffer {
  const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * 统一的未授权响应
 */
export function unauthorizedResponse(message = 'Unauthorized'): Response {
  return new Response(
    JSON.stringify({ error: { code: 'UNAUTHORIZED', message } }),
    {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}
