import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import {
  Env,
  SyncBootstrapRequest,
  SyncBootstrapResponse,
  SyncPullRequest,
  SyncPullResponse,
  SyncPushRequest,
  SyncPushResponse,
  SyncRegisterDeviceRequest,
  SyncRegisterDeviceResponse,
} from '../types';
import { errorResponse, jsonResponse, supabaseRpc } from '../utils/supabase';

const MAX_MUTATIONS_PER_PUSH = 100;
const MAX_PULL_LIMIT = 500;
const MAX_BOOTSTRAP_LIMIT = 500;

export async function handleRegisterSyncDevice(
  request: Request,
  env: Env,
  auth: AuthPayload
): Promise<Response> {
  const body = await parseJsonBody<SyncRegisterDeviceRequest>(request);
  if (!body) {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  if (!body.device_id || !body.platform) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required fields: device_id, platform');
  }

  const resp = await supabaseRpc(env, 'sync_register_device', {
    p_user_id: auth.sub,
    p_device_id: body.device_id,
    p_platform: body.platform,
    p_device_name: body.device_name ?? null,
    p_app_version: body.app_version ?? null,
  });

  return relayRpcResponse<SyncRegisterDeviceResponse>(request, resp, 'Failed to register sync device');
}

export async function handleSyncBootstrap(
  request: Request,
  env: Env,
  auth: AuthPayload
): Promise<Response> {
  const url = new URL(request.url);
  const deviceId = url.searchParams.get('device_id');
  const cursor = url.searchParams.get('cursor');
  const limit = clampInt(url.searchParams.get('limit'), 200, 1, MAX_BOOTSTRAP_LIMIT);

  if (!deviceId) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required query: device_id');
  }

  const payload: SyncBootstrapRequest = {
    device_id: deviceId,
    cursor,
    limit,
  };

  const resp = await supabaseRpc(env, 'sync_bootstrap', {
    p_user_id: auth.sub,
    p_device_id: payload.device_id,
    p_cursor: payload.cursor ?? null,
    p_limit: payload.limit ?? 200,
  });

  return relayRpcResponse<SyncBootstrapResponse>(request, resp, 'Failed to bootstrap sync state');
}

export async function handleSyncPull(
  request: Request,
  env: Env,
  auth: AuthPayload
): Promise<Response> {
  const url = new URL(request.url);
  const deviceId = url.searchParams.get('device_id');
  const afterSeq = clampInt(url.searchParams.get('after_seq'), 0, 0, Number.MAX_SAFE_INTEGER);
  const limit = clampInt(url.searchParams.get('limit'), 200, 1, MAX_PULL_LIMIT);

  if (!deviceId) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required query: device_id');
  }

  const payload: SyncPullRequest = {
    device_id: deviceId,
    after_seq: afterSeq,
    limit,
  };

  const resp = await supabaseRpc(env, 'sync_pull', {
    p_user_id: auth.sub,
    p_device_id: payload.device_id,
    p_after_seq: payload.after_seq ?? 0,
    p_limit: payload.limit ?? 200,
  });

  return relayRpcResponse<SyncPullResponse>(request, resp, 'Failed to pull sync events');
}

export async function handleSyncPush(
  request: Request,
  env: Env,
  auth: AuthPayload
): Promise<Response> {
  const body = await parseJsonBody<SyncPushRequest>(request);
  if (!body) {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  if (!body.device_id) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required field: device_id');
  }

  if (!Array.isArray(body.mutations)) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required field: mutations');
  }

  if (body.mutations.length > MAX_MUTATIONS_PER_PUSH) {
    return errorResponse(400, 'BAD_REQUEST', `mutations exceeds limit ${MAX_MUTATIONS_PER_PUSH}`);
  }

  for (const mutation of body.mutations) {
    if (!mutation.mutation_id || !mutation.entity_type || !mutation.entity_key || !mutation.operation) {
      return errorResponse(
        400,
        'BAD_REQUEST',
        'Each mutation requires mutation_id, entity_type, entity_key, and operation'
      );
    }
  }

  const resp = await supabaseRpc(env, 'sync_push', {
    p_user_id: auth.sub,
    p_device_id: body.device_id,
    p_known_cursor: body.known_cursor ?? null,
    p_mutations: body.mutations,
  });

  return relayRpcResponse<SyncPushResponse>(request, resp, 'Failed to push sync mutations');
}

async function parseJsonBody<T>(request: Request): Promise<T | null> {
  try {
    return await request.json<T>();
  } catch {
    return null;
  }
}

function clampInt(
  raw: string | null,
  fallback: number,
  min: number,
  max: number
): number {
  if (!raw) return fallback;

  const parsed = parseInt(raw, 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
}

async function relayRpcResponse<T>(
  request: Request,
  response: Response,
  fallbackMessage: string
): Promise<Response> {
  if (!response.ok) {
    const text = await response.text();
    return errorResponse(500, 'DB_ERROR', `${fallbackMessage}: ${text}`);
  }

  const body = (await response.json()) as T;
  return jsonResponse(body, corsHeaders(request));
}