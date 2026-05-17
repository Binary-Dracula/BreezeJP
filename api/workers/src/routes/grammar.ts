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
    fetchGrammarRows(env, grammarParams),
    supabaseFetch(env, '/user_grammar_states', {
      select: 'grammar_id,learning_status',
      user_id: `eq.${auth.sub}`,
      limit: '2000',
    }),
  ]);

  if (!grammarResp.ok) {
    const supabaseBody = await grammarResp.clone().text();
    console.error(
      `Grammar list content query failed: ${grammarResp.status} ${grammarResp.statusText}`,
      supabaseBody,
    );
    return new Response(
      JSON.stringify({
        error: {
          code: 'DB_ERROR',
          message: `Failed to fetch grammar list`,
          debug: { supabase_status: grammarResp.status, supabase_body: supabaseBody },
        },
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(request) } },
    );
  }

  const grammars = (await grammarResp.json()) as GrammarRow[];
  const states = await readOptionalGrammarStates(
    stateResp,
    'Failed to fetch grammar list states',
  );
  const stateById = new Map(states.map((row) => [row.grammar_id, row.learning_status]));

  const candidates = grammars.filter((grammar) => {
    if (excludeIds.has(grammar.id)) {
      return false;
    }

    const status = stateById.get(grammar.id) ?? 0;
    return !unlearnedOnly || status === 0;
  });

  // 列表端点只需要 grammar + learning_status；GrammarListController 只读 detail.grammar
  // 不调用 fetchGrammarDetailBundle，避免 N×5 Supabase 请求（严重超时/限额问题）
  const details = candidates.slice(0, limit).map((grammar) => ({
    grammar,
    meanings: [],
    contexts: [],
    examples: [],
    learning_status: stateById.get(grammar.id) ?? 0,
    learning_state: null,
  }));

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

  const failedContentResponse = [
    { resource: 'grammar', response: grammarResp },
    { resource: 'grammar_meanings', response: meaningsResp },
    { resource: 'grammar_contexts', response: contextsResp },
    { resource: 'grammar_examples', response: examplesResp },
  ].find(({ response }) => !response.ok);
  if (failedContentResponse) {
    await logSupabaseFailure(
      `Failed to fetch grammar detail ${failedContentResponse.resource} for grammar ${grammarId}`,
      failedContentResponse.response,
    );
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
  const stateRows = await readOptionalGrammarStates(
    stateResp,
    `Failed to fetch grammar detail state for grammar ${grammarId}`,
  );
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

async function fetchGrammarRows(
  env: Env,
  grammarParams: Record<string, string>,
): Promise<Response> {
  const response = await supabaseFetch(env, '/grammars', grammarParams);
  if (response.ok || grammarParams.order !== 'usage_frequency.desc,id.asc') {
    return response;
  }

  const errorBody = await response.clone().text();
  if (!errorBody.toLowerCase().includes('usage_frequency')) {
    return response;
  }

  console.warn(
    'Grammar list query failed on usage_frequency order; retrying with id.asc:',
    errorBody,
  );
  return supabaseFetch(env, '/grammars', {
    ...grammarParams,
    order: 'id.asc',
  });
}

async function readOptionalGrammarStates(
  response: Response,
  context: string,
): Promise<UserGrammarStateRow[]> {
  if (!response.ok) {
    await logSupabaseFailure(context, response, 'warn');
    return [];
  }

  return (await response.json()) as UserGrammarStateRow[];
}

async function logSupabaseFailure(
  context: string,
  response: Response,
  level: 'error' | 'warn' = 'error',
): Promise<void> {
  const body = await response.clone().text();
  if (level === 'warn') {
    console.warn(`${context}: ${response.status} ${response.statusText}`, body);
    return;
  }

  console.error(`${context}: ${response.status} ${response.statusText}`, body);
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

  const normalized = raw.trim().toLowerCase();
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