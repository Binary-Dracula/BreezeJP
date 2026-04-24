import { Env } from '../types';
import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { supabaseFetch, errorResponse } from '../utils/supabase';

/**
 * POST /api/v1/issues — 用户提交问题上报
 */
export async function handleCreateIssue(
  request: Request,
  env: Env,
  auth: AuthPayload
): Promise<Response> {
  const body = await request.json() as Record<string, unknown>;
  const { content_type, content_id, content_snapshot, message } = body;

  // 参数校验
  if (!content_type || !content_id || !content_snapshot) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required fields: content_type, content_id, content_snapshot');
  }
  if (content_type !== 'word' && content_type !== 'grammar') {
    return errorResponse(400, 'BAD_REQUEST', 'content_type must be "word" or "grammar"');
  }

  const row = {
    user_id: auth.sub,
    content_type,
    content_id: String(content_id),
    content_snapshot,
    message: message ? String(message) : null,
  };

  const resp = await supabaseFetch(env, '/issue_reports', undefined, {
    method: 'POST',
    body: row,
    headers: { 'Prefer': 'return=minimal' },
  });

  if (!resp.ok) {
    const text = await resp.text();
    return errorResponse(500, 'DB_ERROR', `Failed to create issue: ${text}`);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 201,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(request),
    },
  });
}
