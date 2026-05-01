import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env, ReviewSessionEnvelope, ReviewSessionPhase, ReviewSessionStatus, ReviewSessionUpdateRequest, VocabFullDetail, VocabWord } from '../types';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';
import { fetchFullDetailsBatch } from './vocab';

type UserWordStateRow = {
  word_id: string;
  book_id: string;
  user_state: number;
  next_review_at: number | null;
  last_reviewed_at: number | null;
  first_learned_at: number | null;
  interval: number | null;
  ease_factor: number | null;
  stability: number | null;
  difficulty: number | null;
  streak: number;
  total_reviews: number;
  fail_count: number;
  created_at: string;
  updated_at: string;
};

type UserWordBookRow = {
  study_word_id: number;
  word_id: string;
  book_id: string;
  word: string;
  reading: string;
  romaji?: string | null;
  jlpt_level?: string | null;
  part_of_speech?: string | null;
  primary_meaning?: string | null;
  has_audio: boolean;
  user_state: number;
  updated_at: number;
};

type UserWordExampleFavoriteRow = {
  example_id: string;
  word_id: string;
  word: string;
  reading: string;
  jlpt_level?: string | null;
  part_of_speech?: string | null;
  primary_meaning?: string | null;
  japanese: string;
  chinese: string;
  has_audio: boolean;
  updated_at: number;
};

type UserGrammarBookRow = {
  study_grammar_id: number;
  grammar_id: number;
  title: string;
  jlpt_level?: string | null;
  learning_status: number;
  updated_at: number;
};

type WordReviewSessionItem = {
  word_state: UserWordStateRow;
  word_detail: VocabFullDetail;
  question_type: WordReviewQuestionType;
  audio_source: string | null;
  meaning: string | null;
  reading: string | null;
  options: string[];
};

type WordReviewQuestionType =
  | 'word_to_meaning'
  | 'audio_to_meaning'
  | 'kanji_to_reading'
  | 'meaning_to_spelling';

// Worker 当前只暴露 word review session；kana review 已迁回本地状态流。
type ReviewSessionKind = 'word';

type ReviewSessionRow = {
  id: string;
  user_id: string;
  session_kind: ReviewSessionKind;
  status: ReviewSessionStatus;
  current_index: number;
  current_phase: ReviewSessionPhase;
  has_mistake_on_current: boolean;
  items: unknown[];
  created_at: string;
  updated_at: string;
  closed_at: string | null;
};

const MAX_SESSION_LIMIT = 50;
const MAX_BOOK_LIMIT = 100;
const kanaOptionPool = [
  'あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'け', 'こ', 'が', 'ぎ', 'ぐ', 'げ', 'ご',
  'さ', 'し', 'す', 'せ', 'そ', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'た', 'ち', 'つ', 'て', 'と',
  'だ', 'ぢ', 'づ', 'で', 'ど', 'な', 'に', 'ぬ', 'ね', 'の', 'は', 'ひ', 'ふ', 'へ', 'ほ',
  'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ま', 'み', 'む', 'め', 'も',
  'や', 'ゆ', 'よ', 'ら', 'り', 'る', 'れ', 'ろ', 'わ', 'を', 'ん',
];

export async function handleWordReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const activeSession = await getActiveReviewSession(env, auth.sub, 'word');
  if (activeSession) {
    return jsonResponse(
      {
        data: toStoredReviewSession<WordReviewSessionItem>(activeSession),
        meta: {
          count: activeSession.items.length,
          resumed: true,
          server_time: new Date().toISOString(),
        },
      },
      corsHeaders(request),
    );
  }

  const url = new URL(request.url);
  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_SESSION_LIMIT);
  const nowSeconds = Math.floor(Date.now() / 1000);

  const stateResp = await supabaseFetch(env, '/user_word_states', {
    select: '*',
    user_id: `eq.${auth.sub}`,
    user_state: 'eq.1',
    or: `(next_review_at.is.null,next_review_at.lte.${nowSeconds})`,
    order: 'next_review_at.asc.nullsfirst',
    limit: String(limit),
  });

  if (!stateResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch due word reviews');
  }

  const stateRows = (await stateResp.json()) as UserWordStateRow[];
  if (stateRows.length === 0) {
    return jsonResponse(
      {
        data: emptyReviewSession<WordReviewSessionItem>(),
        meta: {
          count: 0,
          resumed: false,
          server_time: new Date().toISOString(),
        },
      },
      corsHeaders(request),
    );
  }

  const detailsById = await fetchFullDetailsBatch(
    env,
    stateRows.map((row) => row.word_id),
  );
  const distractorPool = await fetchWordDistractorPool(env);
  const sessionDetails = stateRows
    .map((row) => detailsById.get(row.word_id))
    .filter((detail): detail is VocabFullDetail => detail != null);

  const items = stateRows
    .map((row) => buildWordReviewItem(request, auth, row, detailsById.get(row.word_id), distractorPool, sessionDetails))
    .filter((item): item is WordReviewSessionItem => item != null);

  if (items.length === 0) {
    return jsonResponse(
      {
        data: emptyReviewSession<WordReviewSessionItem>(),
        meta: { count: 0, resumed: false, server_time: new Date().toISOString() },
      },
      corsHeaders(request),
    );
  }

  const createdSession = await createReviewSession(env, auth.sub, 'word', items);

  return jsonResponse(
    {
      data: toStoredReviewSession<WordReviewSessionItem>(createdSession),
      meta: { count: items.length, resumed: false, server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleUpdateWordReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  return handleUpdateReviewSession<WordReviewSessionItem>(
    request,
    env,
    auth,
    'word',
  );
}

export async function handleWordBook(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const url = new URL(request.url);
  const rawStatus = url.searchParams.get('status');

  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_BOOK_LIMIT);
  const offset = clampInt(url.searchParams.get('offset'), 0, 0, Number.MAX_SAFE_INTEGER);
  const search = sanitizeSearchTerm(url.searchParams.get('search'));
  const params: Record<string, string> = {
    select: '*',
    user_id: `eq.${auth.sub}`,
    order: 'updated_at.desc',
    limit: String(limit),
    offset: String(offset),
  };

  let resource = '/user_word_book_view';
  if (rawStatus === 'favorite') {
    resource = '/user_word_favorite_book_view';
  } else {
    const status = resolveWordBookStatus(rawStatus);
    if (status == null) {
      return errorResponse(400, 'BAD_REQUEST', 'Invalid word book status');
    }
    params.user_state = `eq.${status}`;
  }

  if (search) {
    params.or = `(word.ilike.*${search}*,reading.ilike.*${search}*,primary_meaning.ilike.*${search}*,romaji.ilike.*${search}*)`;
  }

  const response = await supabaseFetch(env, resource, params);
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch word book');
  }

  const rows = (await response.json()) as UserWordBookRow[];
  const totalCount = parseContentRangeTotal(response.headers.get('content-range')) ?? rows.length;
  return jsonResponse(
    {
      data: rows,
      meta: {
        total_count: totalCount,
        has_more: offset + rows.length < totalCount,
        server_time: new Date().toISOString(),
      },
    },
    corsHeaders(request),
  );
}

export async function handleWordExampleFavorites(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const url = new URL(request.url);
  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_BOOK_LIMIT);
  const offset = clampInt(url.searchParams.get('offset'), 0, 0, Number.MAX_SAFE_INTEGER);
  const search = sanitizeSearchTerm(url.searchParams.get('search'));
  const params: Record<string, string> = {
    select: '*',
    user_id: `eq.${auth.sub}`,
    order: 'updated_at.desc',
    limit: String(limit),
    offset: String(offset),
  };

  if (search) {
    params.or = `(word.ilike.*${search}*,reading.ilike.*${search}*,primary_meaning.ilike.*${search}*,japanese.ilike.*${search}*,chinese.ilike.*${search}*)`;
  }

  const response = await supabaseFetch(env, '/user_word_example_favorite_view', params);
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch example favorites');
  }

  const rows = (await response.json()) as UserWordExampleFavoriteRow[];
  const totalCount = parseContentRangeTotal(response.headers.get('content-range')) ?? rows.length;
  return jsonResponse(
    {
      data: rows,
      meta: {
        total_count: totalCount,
        has_more: offset + rows.length < totalCount,
        server_time: new Date().toISOString(),
      },
    },
    corsHeaders(request),
  );
}

export async function handleGrammarBook(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const url = new URL(request.url);
  const status = resolveGrammarBookStatus(url.searchParams.get('status'));
  if (status == null) {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid grammar book status');
  }

  const limit = clampInt(url.searchParams.get('limit'), 20, 1, MAX_BOOK_LIMIT);
  const offset = clampInt(url.searchParams.get('offset'), 0, 0, Number.MAX_SAFE_INTEGER);
  const search = sanitizeSearchTerm(url.searchParams.get('search'));
  const params: Record<string, string> = {
    select: '*',
    user_id: `eq.${auth.sub}`,
    learning_status: `eq.${status}`,
    order: 'updated_at.desc',
    limit: String(limit),
    offset: String(offset),
  };

  if (search) {
    params.title = `ilike.*${search}*`;
  }

  const response = await supabaseFetch(env, '/user_grammar_book_view', params);
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch grammar book');
  }

  const rows = (await response.json()) as UserGrammarBookRow[];
  const totalCount = parseContentRangeTotal(response.headers.get('content-range')) ?? rows.length;
  return jsonResponse(
    {
      data: rows,
      meta: {
        total_count: totalCount,
        has_more: offset + rows.length < totalCount,
        server_time: new Date().toISOString(),
      },
    },
    corsHeaders(request),
  );
}

function buildWordReviewItem(
  request: Request,
  auth: AuthPayload,
  row: UserWordStateRow,
  detail: VocabFullDetail | undefined,
  distractorPool: VocabWord[],
  sessionDetails: VocabFullDetail[],
): WordReviewSessionItem | null {
  if (!detail) {
    return null;
  }

  const meaning = pickWordMeaning(detail);
  const reading = pickWordReading(detail);
  const availableTypes = collectWordReviewTypes(meaning, reading);
  if (availableTypes.length === 0) {
    return null;
  }

  const questionType = chooseWordReviewType(auth.sub, row, detail.word, availableTypes);
  return {
    word_state: row,
    word_detail: detail,
    question_type: questionType,
    audio_source: detail.has_audio
      ? new URL(`/api/v1/audio/words/${row.word_id}`, request.url).toString()
      : null,
    meaning,
    reading,
    options: buildWordReviewOptions(questionType, meaning, reading, distractorPool, sessionDetails),
  };
}

function buildWordReviewOptions(
  questionType: WordReviewQuestionType,
  meaning: string | null,
  reading: string | null,
  distractorPool: VocabWord[],
  sessionDetails: VocabFullDetail[],
): string[] {
  if (questionType === 'meaning_to_spelling') {
    const correctChars = (reading ?? '').split('').filter((char) => char.length > 0);
    return shuffleArray(uniqueStrings([...correctChars, ...kanaOptionPool.slice(0, 4)]));
  }

  const options: string[] = [];
  if (questionType === 'word_to_meaning' || questionType === 'audio_to_meaning') {
    if (meaning) {
      options.push(meaning);
    }
    for (const candidate of distractorPool) {
      const value = candidate.primary_meaning?.trim();
      if (value && !options.includes(value)) {
        options.push(value);
      }
      if (options.length >= 4) {
        break;
      }
    }
    for (const detail of sessionDetails) {
      const value = pickWordMeaning(detail);
      if (value && !options.includes(value)) {
        options.push(value);
      }
      if (options.length >= 4) {
        break;
      }
    }
    return shuffleArray(options.slice(0, 4));
  }

  if (reading) {
    options.push(reading);
  }
  for (const candidate of distractorPool) {
    const value = candidate.reading.trim();
    if (value && !options.includes(value)) {
      options.push(value);
    }
    if (options.length >= 4) {
      break;
    }
  }
  for (const detail of sessionDetails) {
    const value = pickWordReading(detail);
    if (value && !options.includes(value)) {
      options.push(value);
    }
    if (options.length >= 4) {
      break;
    }
  }
  return shuffleArray(options.slice(0, 4));
}

function collectWordReviewTypes(
  meaning: string | null,
  reading: string | null,
): WordReviewQuestionType[] {
  const result: WordReviewQuestionType[] = [];
  if (meaning) {
    result.push('word_to_meaning', 'meaning_to_spelling');
  }
  if (reading) {
    result.push('kanji_to_reading');
  }
  return result;
}

function chooseWordReviewType(
  userId: string,
  row: UserWordStateRow,
  word: string,
  available: WordReviewQuestionType[],
): WordReviewQuestionType {
  const bucket = Math.abs(simpleHash(`${userId}:${row.word_id}:${row.total_reviews}`)) % 10;
  if (row.total_reviews === 0) {
    return available.includes('word_to_meaning') ? 'word_to_meaning' : available[0];
  }
  if (
    bucket < 4 &&
    available.includes('kanji_to_reading') &&
    /[\u4e00-\u9faf]/.test(word)
  ) {
    return 'kanji_to_reading';
  }
  if (available.includes('meaning_to_spelling')) {
    return 'meaning_to_spelling';
  }
  return available[0];
}

async function fetchWordDistractorPool(env: Env): Promise<VocabWord[]> {
  const response = await supabaseFetch(env, '/words', {
    select: 'id,word,reading,primary_meaning,has_audio',
    order: 'updated_at.desc',
    limit: '200',
  });

  if (!response.ok) {
    return [];
  }

  return (await response.json()) as VocabWord[];
}

function pickWordMeaning(detail: VocabFullDetail): string | null {
  if (detail.primary_meaning && detail.primary_meaning.trim().length > 0) {
    return detail.primary_meaning.trim();
  }

  const firstMeaning = detail.rich_content.meanings.find((entry) => {
    const value = typeof entry.meaning === 'string' ? entry.meaning.trim() : '';
    return value.length > 0;
  });
  if (!firstMeaning) {
    return null;
  }
  return typeof firstMeaning.meaning === 'string' ? firstMeaning.meaning.trim() : null;
}

function pickWordReading(detail: VocabFullDetail): string | null {
  const reading = detail.reading.trim();
  if (reading.length > 0) {
    return reading;
  }
  const romaji = detail.romaji?.trim();
  return romaji && romaji.length > 0 ? romaji : null;
}

function resolveWordBookStatus(raw: string | null): number | null {
  switch (raw) {
    case 'learning':
      return 1;
    case 'mastered':
      return 2;
    case 'ignored':
      return 3;
    default:
      return null;
  }
}

function resolveGrammarBookStatus(raw: string | null): number | null {
  switch (raw) {
    case 'learning':
      return 1;
    case 'mastered':
      return 2;
    default:
      return null;
  }
}

function sanitizeSearchTerm(raw: string | null): string | null {
  if (!raw) {
    return null;
  }
  const trimmed = raw.trim().replace(/[*,()]/g, '');
  return trimmed.length > 0 ? trimmed : null;
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

function parseContentRangeTotal(contentRange: string | null): number | null {
  if (!contentRange) {
    return null;
  }
  const match = contentRange.match(/\/(\d+)$/);
  return match ? Number.parseInt(match[1], 10) : null;
}

function simpleHash(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) - hash) + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}

function shuffleArray<T>(values: T[]): T[] {
  const result = [...values];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    const current = result[index];
    result[index] = result[swapIndex];
    result[swapIndex] = current;
  }
  return result;
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value.trim().length > 0)));
}

async function getActiveReviewSession(
  env: Env,
  userId: string,
  kind: ReviewSessionKind,
): Promise<ReviewSessionRow | null> {
  const response = await supabaseFetch(env, '/user_review_sessions', {
    select: '*',
    user_id: `eq.${userId}`,
    session_kind: `eq.${kind}`,
    status: 'eq.active',
    order: 'updated_at.desc',
    limit: '1',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch active ${kind} review session`);
  }

  const rows = (await response.json()) as ReviewSessionRow[];
  return rows[0] ?? null;
}

async function getReviewSessionById(
  env: Env,
  userId: string,
  kind: ReviewSessionKind,
  sessionId: string,
): Promise<ReviewSessionRow | null> {
  const response = await supabaseFetch(env, '/user_review_sessions', {
    select: '*',
    id: `eq.${sessionId}`,
    user_id: `eq.${userId}`,
    session_kind: `eq.${kind}`,
    limit: '1',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch ${kind} review session by id`);
  }

  const rows = (await response.json()) as ReviewSessionRow[];
  return rows[0] ?? null;
}

async function createReviewSession<TItem>(
  env: Env,
  userId: string,
  kind: ReviewSessionKind,
  items: TItem[],
): Promise<ReviewSessionRow> {
  const response = await supabaseFetch(
    env,
    '/user_review_sessions',
    undefined,
    {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: {
        user_id: userId,
        session_kind: kind,
        status: 'active',
        current_index: 0,
        current_phase: 'testing',
        has_mistake_on_current: false,
        items,
        closed_at: null,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`Failed to create ${kind} review session`);
  }

  const rows = (await response.json()) as ReviewSessionRow[];
  if (!rows[0]) {
    throw new Error(`Empty response while creating ${kind} review session`);
  }
  return rows[0];
}

async function handleUpdateReviewSession<TItem>(
  request: Request,
  env: Env,
  auth: AuthPayload,
  kind: ReviewSessionKind,
): Promise<Response> {
  let body: ReviewSessionUpdateRequest<TItem>;
  try {
    body = await request.json<ReviewSessionUpdateRequest<TItem>>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid review session payload');
  }

  if (!body.session_id || body.session_id.trim().length === 0) {
    return errorResponse(400, 'BAD_REQUEST', 'session_id is required');
  }

  const existing = await getReviewSessionById(env, auth.sub, kind, body.session_id);
  if (!existing) {
    return errorResponse(404, 'SESSION_NOT_FOUND', 'Review session not found');
  }
  if (existing.status !== 'active') {
    return errorResponse(409, 'SESSION_CLOSED', 'Review session is already closed');
  }

  const currentPhase = body.current_phase ?? existing.current_phase;
  if (currentPhase !== 'testing' && currentPhase !== 'grading') {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid current_phase');
  }

  const currentIndexRaw = body.current_index ?? existing.current_index;
  const currentIndex = Number.isFinite(currentIndexRaw)
    ? Math.max(0, Math.trunc(currentIndexRaw))
    : existing.current_index;

  const items = Array.isArray(body.items) ? body.items : (existing.items as TItem[]);
  const status: ReviewSessionStatus = body.is_finished === true ? 'completed' : 'active';

  const response = await supabaseFetch(
    env,
    '/user_review_sessions',
    {
      id: `eq.${body.session_id}`,
      user_id: `eq.${auth.sub}`,
      session_kind: `eq.${kind}`,
    },
    {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: {
        current_index: currentIndex,
        current_phase: currentPhase,
        has_mistake_on_current: body.has_mistake_on_current === true,
        items,
        status,
        closed_at: body.is_finished === true ? new Date().toISOString() : null,
      },
    },
  );

  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to update review session');
  }

  const rows = (await response.json()) as ReviewSessionRow[];
  const updated = rows[0];
  if (!updated) {
    return errorResponse(500, 'DB_ERROR', 'Empty review session update response');
  }

  return jsonResponse(
    {
      data: {
        session_id: updated.id,
        status: updated.status,
        current_index: updated.current_index,
        current_phase: updated.current_phase,
        has_mistake_on_current: updated.has_mistake_on_current,
      },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

function emptyReviewSession<TItem>(): ReviewSessionEnvelope<TItem> {
  return {
    session_id: null,
    current_index: 0,
    current_phase: 'testing',
    has_mistake_on_current: false,
    items: [],
  };
}

function toStoredReviewSession<TItem>(
  session: ReviewSessionRow,
): ReviewSessionEnvelope<TItem> {
  return {
    session_id: session.id,
    current_index: session.current_index,
    current_phase: session.current_phase,
    has_mistake_on_current: session.has_mistake_on_current,
    items: Array.isArray(session.items) ? (session.items as TItem[]) : [],
  };
}