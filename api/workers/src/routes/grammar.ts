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

export async function handleGrammarLearningQueue(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const url = new URL(request.url);
  const limit = clampInt(url.searchParams.get('limit'), 5, 1, 20);
  const excludeIds = parseExcludeIds(url.searchParams.get('exclude_ids'));

  const [grammarResp, stateResp] = await Promise.all([
    supabaseFetch(env, '/grammars', {
      select: '*',
      order: 'usage_frequency.desc,id.asc',
      limit: '2000',
    }),
    supabaseFetch(env, '/user_grammar_states', {
      select: 'grammar_id,learning_status',
      user_id: `eq.${auth.sub}`,
      limit: '2000',
    }),
  ]);

  if (!grammarResp.ok || !stateResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch grammar queue');
  }

  const grammars = (await grammarResp.json()) as GrammarRow[];
  const states = (await stateResp.json()) as UserGrammarStateRow[];
  const stateById = new Map(states.map((row) => [row.grammar_id, row.learning_status]));
  const excluded = new Set(excludeIds);

  const candidates = grammars.filter((grammar) => {
    if (excluded.has(grammar.id)) {
      return false;
    }
    const status = stateById.get(grammar.id);
    return status == null || status === 0;
  });

  shuffle(candidates);

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
      select: 'learning_status',
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
  const stateRows = (await stateResp.json()) as Array<{ learning_status: number }>;

  return {
    grammar,
    meanings,
    contexts,
    examples,
    learning_status: stateRows[0]?.learning_status ?? 0,
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

function shuffle<T>(values: T[]): void {
  for (let index = values.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    const current = values[index];
    values[index] = values[swapIndex];
    values[swapIndex] = current;
  }
}