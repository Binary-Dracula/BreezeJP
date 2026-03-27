// 音频代理路由
// GET /api/v1/audio/:id - 从 R2 读取音频并流式返回
// R2 路径规则：audio/audio_articles/{article_id}.mp3
// （与 audio_examples 和 audio_words 并列在 audio/ 目录下）

import { Env } from '../types';
import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';

export async function handleAudio(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  id: string
): Promise<Response> {
  const objectKey = `audio/audio_articles/${id}.mp3`;

  // 支持 HTTP Range 请求（音频拖拽进度条需要）
  const rangeHeader = request.headers.get('Range');

  const object = rangeHeader
    ? await env.AUDIO_BUCKET.get(objectKey, { range: parseRange(rangeHeader) })
    : await env.AUDIO_BUCKET.get(objectKey);

  if (!object) {
    return new Response(
      JSON.stringify({ error: { code: 'NOT_FOUND', message: `Audio for '${id}' not found` } }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const headers: Record<string, string> = {
    'Content-Type': 'audio/mpeg',
    'Cache-Control': 'public, max-age=31536000, immutable', // 音频永不变更，永久缓存
    'Accept-Ranges': 'bytes',
    'Content-Length': object.size.toString(),
    ...corsHeaders(request),
  };

  // 设置 Content-Range（分片响应）
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
 * 解析 HTTP Range 头
 * e.g. "bytes=0-1023" → { offset: 0, length: 1024 }
 */
function parseRange(rangeHeader: string): { offset: number; length: number } | undefined {
  const match = rangeHeader.match(/^bytes=(\d+)-(\d*)$/);
  if (!match) return undefined;
  const offset = parseInt(match[1], 10);
  const end = match[2] ? parseInt(match[2], 10) : undefined;
  const length = end !== undefined ? end - offset + 1 : undefined;
  return length !== undefined ? { offset, length } : { offset, length: 1024 * 1024 }; // 默认 1MB
}
