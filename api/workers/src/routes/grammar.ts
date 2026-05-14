import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env } from '../types';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';

type GrammarRow = {
  id: number;
  title: string;
  jlpt_level: string | null;
  usage_frequency: number;
  created_at: string;
  updated_at: string;
};

type GrammarMeaningRow = {
  id: number;
  grammar_id: number;
  sort_order: number;
  definition_cn: string | null;
  definition_en: string | null;
  how_to_use_cn: string | null;
  how_to_use_en: string | null;
};

type GrammarContextRow = {
  id: number;
  grammar_id: number;
  when_to_use_cn: string | null;
  when_to_use_en: string | null;
};

type GrammarExampleRow = {
  id: number;
  grammar_id: number;
  sort_order: number;
  sentence: string | null;
  translation_cn: string | null;
  translation_en: string | null;
  audio_url: string | null;
};

type UserGrammarStateRow = {
  grammar_id: number;
  learning_status: number;
  next_review_at: number | null;
  last_reviewed_at: number | null;
  streak: number;
  total_reviews: number;
  fail_count: number;
  interval: number;
  ease_factor: number;
  stability: number;
  difficulty: number;
  created_at: string;
  updated_at: string;
};

type GrammarStatePayload = {
  grammar_id?: number;
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

export async function handleGrammarDetail(
  request: Request,
  env: Env,
  auth: AuthPayload,
  grammarId: number,
): Promise<Response> {
  if (!Number.isInteger(grammarId) || grammarId <= 0) {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid grammar id');
  }

  const detail = await fetchGrammarDetailBundle(env, auth.sub, grammarId);
  if (detail == null) {
    return errorResponse(404, 'GRAMMAR_NOT_FOUND', 'Grammar not found');
  }

  return jsonResponse(
    {
      data: detail,
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleGrammarList(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const url = new URL(request.url);
  const limit = clampInt(url.searchParams.get('limit'), 20, 1, 50);
  const excludeIds = new Set(parseExcludeIds(url.searchParams.get('exclude_ids')));
  const unlearnedOnly = url.searchParams.get('unlearned_only') === 'true';
  const jlptLevel = sanitizeJlptLevel(url.searchParams.get('jlpt_level'));
  const grammarParams: Record<string, string> = {
    select: '*',
    order: 'usage_frequency.desc,id.asc',
    limit: '2000',
  };
  if (jlptLevel != null) {
    grammarParams.jlpt_level = `eq.${jlptLevel}`;
  }

  const [grammarResp, stateResp] = await Promise.all([
    supabaseFetch(env, '/grammars', grammarParams),
    supabaseFetch(env, '/user_grammar_states', {
      select: 'grammar_id,learning_status',
      user_id: `eq.${auth.sub}`,
      limit: '2000',
    }),
  ]);

  if (!grammarResp.ok || !stateResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch grammar list');
  }

  const grammars = (await grammarResp.json()) as GrammarRow[];
  const states = (await stateResp.json()) as UserGrammarStateRow[];
  const stateById = new Map(states.map((row) => [row.grammar_id, row.learning_status]));

  const candidates = grammars.filter((grammar) => {
    if (excludeIds.has(grammar.id)) {
      return false;
    }

    const status = stateById.get(grammar.id) ?? 0;
    return !unlearnedOnly || status === 0;
  });


  const details = [];
  for (const grammar of candidates.slice(0, limit)) {
    const detail = await fetchGrammarDetailBundle(env, auth.sub, grammar.id);
    if (detail != null) {
      details.push(detail);
    }
  }

  return jsonResponse(
    {
      data: details,
      meta: {
        count: details.length,
        server_time: new Date().toISOString(),
      },
    },
    corsHeaders(request),
  );
}

export async function handleGrammarStates(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: { states?: GrammarStatePayload[] };
  try {
    body = await request.json<{ states?: GrammarStatePayload[] }>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  const states = (body.states ?? [])
    .map((state) => normalizeGrammarState(state, auth.sub))
    .filter((state): state is Record<string, unknown> => state != null);
  if (states.length === 0) {
    return errorResponse(400, 'BAD_REQUEST', 'No valid grammar states provided');
  }

  const response = await supabaseFetch(
    env,
    '/user_grammar_states',
    { on_conflict: 'user_id,grammar_id' },
    {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
      body: states,
    },
  );
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to upsert grammar states');
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

async function fetchGrammarDetailBundle(
  env: Env,
  userId: string,
  grammarId: number,
): Promise<Record<string, unknown> | null> {
  const [grammarResp, meaningsResp, contextsResp, examplesResp, stateResp] = await Promise.all([
    supabaseFetch(env, '/grammars', {
      select: '*',
      id: `eq.${grammarId}`,
      limit: '1',
    }),
    supabaseFetch(env, '/grammar_meanings', {
      select: '*',
      grammar_id: `eq.${grammarId}`,
      order: 'sort_order.asc,id.asc',
      limit: '200',
    }),
    supabaseFetch(env, '/grammar_contexts', {
      select: '*',
      grammar_id: `eq.${grammarId}`,
      order: 'id.asc',
      limit: '50',
    }),
    supabaseFetch(env, '/grammar_examples', {
      select: '*',
      grammar_id: `eq.${grammarId}`,
      order: 'sort_order.asc,id.asc',
      limit: '500',
    }),
    supabaseFetch(env, '/user_grammar_states', {
      select:
        'grammar_id,learning_status,next_review_at,last_reviewed_at,streak,total_reviews,fail_count,interval,ease_factor,stability,difficulty,created_at,updated_at',
      user_id: `eq.${userId}`,
      grammar_id: `eq.${grammarId}`,
      limit: '1',
    }),
  ]);

  if (!grammarResp.ok || !meaningsResp.ok || !contextsResp.ok || !examplesResp.ok || !stateResp.ok) {
    return null;
  }

  const grammarRows = (await grammarResp.json()) as GrammarRow[];
  const grammar = grammarRows[0];
  if (!grammar) {
    return null;
  }

  const meanings = (await meaningsResp.json()) as GrammarMeaningRow[];
  const contexts = (await contextsResp.json()) as GrammarContextRow[];
  const examples = (await examplesResp.json()) as GrammarExampleRow[];
  const stateRows = (await stateResp.json()) as UserGrammarStateRow[];
  const learningState = stateRows[0] ?? null;

  return {
    grammar,
    meanings,
    contexts,
    examples,
    learning_status: learningState?.learning_status ?? 0,
    learning_state: learningState,
  };
}

function parseExcludeIds(raw: string | null): number[] {
  if (!raw) {
    return [];
  }

  return raw
    .split(',')
    .map((part) => Number.parseInt(part.trim(), 10))
    .filter((value) => Number.isInteger(value) && value > 0);
}

function clampInt(raw: string | null, fallback: number, min: number, max: number): number {
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}

function sanitizeJlptLevel(raw: string | null): string | null {
  if (raw == null) {
    return null;
  }

  const normalized = raw.trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
}

function normalizeGrammarState(
  state: GrammarStatePayload,
  userId: string,
): Record<string, unknown> | null {
  const grammarId = toInt(state.grammar_id);
  const learningStatus = toInt(state.learning_status);
  if (grammarId == null || learningStatus == null) {
    return null;
  }

  return {
    user_id: userId,
    grammar_id: grammarId,
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