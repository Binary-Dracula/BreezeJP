// 音频代理路由
// GET /api/v1/audio/:id - 1.0 新闻音频 (audio/audio_articles/{id}.mp3)
// GET /api/v1/audio/words/:id - 2.0 词汇音频 (audio/words/{id}/main.mp3)

import { Env } from '../types';
import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';

/**
 * 核心 R2 读取与流式返回逻辑
 */
async function fetchFromR2(env: Env, request: Request, objectKey: string): Promise<Response> {
  const rangeHeader = request.headers.get('Range');
  const object = rangeHeader
    ? await env.AUDIO_BUCKET.get(objectKey, { range: parseRange(rangeHeader) })
    : await env.AUDIO_BUCKET.get(objectKey);

  if (!object) {
    return new Response(
      JSON.stringify({ error: { code: 'NOT_FOUND', message: `Audio '${objectKey}' not found` } }),
      { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders(request) } }
    );
  }

  const headers: Record<string, string> = {
    'Content-Type': 'audio/mpeg',
    'Cache-Control': 'public, max-age=31536000, immutable',
    'Accept-Ranges': 'bytes',
    'Content-Length': object.size.toString(),
    ...corsHeaders(request),
  };

  if (rangeHeader && object.range) {
    const range = object.range as { offset: number; length: number };
    const start = range.offset;
    const end = start + range.length - 1;
    headers['Content-Range'] = `bytes ${start}-${end}/${object.size}`;
  }

  return new Response(object.body, {
    status: rangeHeader ? 206 : 200,
    headers,
  });
}

/**
 * GET /api/v1/audio/articles/:id (Legacy)
 */
export async function handleAudio(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  id: string
): Promise<Response> {
  const objectKey = `audio/audio_articles/${id}.mp3`;
  return fetchFromR2(env, request, objectKey);
}

/**
 * GET /api/v1/audio/words/:id
 */
export async function handleWordAudio(
  request: Request,
  env: Env,
  id: string
): Promise<Response> {
  const objectKey = `audio/words/${id}/main.mp3`;
  return fetchFromR2(env, request, objectKey);
}

/**
 * 解析 HTTP Range 头
 */
function parseRange(rangeHeader: string): { offset: number; length: number } | undefined {
  const match = rangeHeader.match(/^bytes=(\d+)-(\d*)$/);
  if (!match) return undefined;
  const offset = parseInt(match[1], 10);
  const end = match[2] ? parseInt(match[2], 10) : undefined;
  const length = end !== undefined ? end - offset + 1 : undefined;
  return length !== undefined ? { offset, length } : { offset, length: 1024 * 1024 };
}
