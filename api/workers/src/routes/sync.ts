import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import {
  Env,
  SyncCheckpointRequest,
  SyncCheckpointResponse,
} from '../types';
import { errorResponse, jsonResponse, supabaseRpc } from '../utils/supabase';

/**
 * POST /api/v1/sync/checkpoint
 *
 * 单次原子同步：
 *   1. push 本地快照（LWW upsert，favorites 全集替换）
 *   2. pull 服务端当前完整状态
 *
 * snapshot 中每个字段为 null/缺省 表示"跳过该实体，不覆盖服务端"。
 * 首次使用新设备时可发送空 snapshot（{} 或省略），仅拉取服务端数据。
 */
export async function handleSyncCheckpoint(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: SyncCheckpointRequest | null = null;
  try {
    body = await request.json<SyncCheckpointRequest>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  if (!body?.device_id) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required field: device_id');
  }

  const snapshot = body.snapshot ?? {};

  const resp = await supabaseRpc(env, 'sync_checkpoint', {
    p_user_id:                auth.sub,
    p_device_id:              body.device_id,
    p_platform:               body.platform ?? 'unknown',
    p_force_takeover:         body.force_takeover ?? false,
    p_profile:                snapshot.profile ?? null,
    p_word_states:            snapshot.word_states ?? null,
    p_word_favorites:         snapshot.word_favorites ?? null,
    p_word_example_favorites: snapshot.word_example_favorites ?? null,
    p_kana_states:            snapshot.kana_states ?? null,
    p_grammar_states:         snapshot.grammar_states ?? null,
    p_book_progress:          snapshot.book_progress ?? null,
  });

  if (!resp.ok) {
    const text = await resp.text();
    return errorResponse(500, 'DB_ERROR', `sync_checkpoint failed: ${text}`);
  }

  const result = (await resp.json()) as SyncCheckpointResponse;
  return jsonResponse(result, corsHeaders(request));
}
