import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env } from '../types';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';

type KanaStatePayload = {
  kana_id?: number;
  learning_status?: number;
  next_review_at?: number | null;
  last_reviewed_at?: number | null;
  streak?: number;
  total_reviews?: number;
  fail_count?: number;
  interval?: number;
  ease_factor?: number;
  stability?: number;
  difficulty?: number;
};

export async function handleKanaStates(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const response = await supabaseFetch(env, '/user_kana_states', {
    select: '*',
    user_id: `eq.${auth.sub}`,
    order: 'kana_id.asc',
    limit: '500',
  });
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch kana states');
  }

  const rows = await response.json();
  return jsonResponse(
    {
      data: rows,
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleUpsertKanaStates(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: KanaStatePayload | { states?: KanaStatePayload[] };
  try {
    body = await request.json<KanaStatePayload | { states?: KanaStatePayload[] }>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  const inputStates = Array.isArray((body as { states?: KanaStatePayload[] }).states)
    ? (body as { states?: KanaStatePayload[] }).states ?? []
    : [body as KanaStatePayload];
  const states = inputStates
    .map((state) => normalizeKanaState(state, auth.sub))
    .filter((state): state is Record<string, unknown> => state != null);

  if (states.length === 0) {
    return errorResponse(400, 'BAD_REQUEST', 'No valid kana states provided');
  }

  const response = await supabaseFetch(
    env,
    '/user_kana_states',
    { on_conflict: 'user_id,kana_id' },
    {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
      body: states,
    },
  );
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to upsert kana states');
  }

  const rows = await response.json();
  return jsonResponse(
    {
      data: rows,
      meta: {
        count: states.length,
        server_time: new Date().toISOString(),
      },
    },
    corsHeaders(request),
  );
}

function normalizeKanaState(
  state: KanaStatePayload,
  userId: string,
): Record<string, unknown> | null {
  const kanaId = toInt(state.kana_id);
  const learningStatus = toInt(state.learning_status);
  if (kanaId == null || learningStatus == null) {
    return null;
  }

  return {
    user_id: userId,
    kana_id: kanaId,
    learning_status: learningStatus,
    next_review_at: toNullableInt(state.next_review_at),
    last_reviewed_at: toNullableInt(state.last_reviewed_at),
    streak: toInt(state.streak),
    total_reviews: toInt(state.total_reviews),
    fail_count: toInt(state.fail_count),
    interval: toNullableNumber(state.interval),
    ease_factor: toNullableNumber(state.ease_factor),
    stability: toNullableNumber(state.stability),
    difficulty: toNullableNumber(state.difficulty),
  };
}

function toInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function toNullableInt(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  return toInt(value);
}

function toNullableNumber(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseFloat(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}
