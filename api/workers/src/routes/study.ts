import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env, ReviewSessionEnvelope, ReviewSessionStatus, VocabExample, VocabFullDetail, VocabWord } from '../types';
import { errorResponse, jsonResponse, supabaseFetch, supabaseRpc } from '../utils/supabase';
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

type UserKanaStateRow = {
  kana_id: number;
  learning_status: number;
  next_review_at: number | null;
  last_reviewed_at: number | null;
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

type KanaLetterRow = {
  id: number;
  kana_char: string;
  script_kind: 'hiragana' | 'katakana';
  romaji: string;
  consonant?: string | null;
  vowel: string;
  row_group?: string | null;
  kana_category?: string | null;
  display_order?: number | null;
  pair_group_id?: number | null;
  audio_id?: number | null;
  mnemonic?: string | null;
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
  /** cloze_test 题型专用：目标单词已替换为 ___ 的例句 */
  cloze_sentence?: string | null;
};

type WordReviewQuestionType =
  | 'word_to_meaning'
  | 'audio_to_meaning'
  | 'kanji_to_reading'
  | 'meaning_to_spelling'
  | 'cloze_test';

type KanaReviewSessionItem = {
  kana_letter: KanaLetterRow;
  learning_state: UserKanaStateRow;
  audio_filename: string | null;
  question_type: KanaReviewQuestionType;
  options: string[];
  counterpart_letter: KanaLetterRow | null;
};

type KanaReviewQuestionType =
  | 'hiragana_to_romaji'
  | 'romaji_to_hiragana'
  | 'katakana_to_romaji'
  | 'romaji_to_katakana'
  | 'hiragana_to_katakana'
  | 'katakana_to_hiragana';

type ReviewRatingValue = 'again' | 'hard' | 'good' | 'easy';

type ReviewSessionCreateRequest = {
  kind?: string;
  limit?: number;
};

type WordReviewResultPayload = {
  word_id?: string;
  book_id?: string;
  rating?: ReviewRatingValue;
};

type KanaReviewResultPayload = {
  kana_id?: number;
  rating?: ReviewRatingValue;
};

type ReviewSessionCompleteRequest = {
  results?: Array<WordReviewResultPayload | KanaReviewResultPayload>;
};

type WordStateRequestPayload = {
  word_id?: string;
  book_id?: string;
  user_state?: number;
  next_review_at?: number | null;
  last_reviewed_at?: number | null;
  first_learned_at?: number | null;
  interval?: number | null;
  ease_factor?: number | null;
  stability?: number | null;
  difficulty?: number | null;
  streak?: number;
  total_reviews?: number;
  fail_count?: number;
  version?: number;
};

type WordStateUpsertPayload = {
  word_id: string;
  book_id: string;
  user_state: number;
  next_review_at: number | null;
  last_reviewed_at: number | null;
  first_learned_at: number | null;
  interval: number | null;
  ease_factor: number | null;
  stability: number;
  difficulty: number;
  streak: number;
  total_reviews: number;
  fail_count: number;
  created_at: number;
  updated_at: number;
  version: number;
};

type ReviewSessionKind = 'word' | 'kana';

type ReviewSessionRow = {
  id: string;
  user_id: string;
  session_kind: ReviewSessionKind;
  status: ReviewSessionStatus;
  current_index: number;
  items: unknown[];
  created_at: string;
  updated_at: string;
  closed_at: string | null;
};

const MAX_SESSION_LIMIT = 50;
const MAX_BOOK_LIMIT = 100;
const REVIEW_SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const kanaOptionPool = [
  'あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'け', 'こ', 'が', 'ぎ', 'ぐ', 'げ', 'ご',
  'さ', 'し', 'す', 'せ', 'そ', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'た', 'ち', 'つ', 'て', 'と',
  'だ', 'ぢ', 'づ', 'で', 'ど', 'な', 'に', 'ぬ', 'ね', 'の', 'は', 'ひ', 'ふ', 'へ', 'ほ',
  'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ま', 'み', 'む', 'め', 'も',
  'や', 'ゆ', 'よ', 'ら', 'り', 'る', 'れ', 'ろ', 'わ', 'を', 'ん',
];

const katakanaOptionPool = [
  'ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ', 'ガ', 'ギ', 'グ', 'ゲ', 'ゴ',
  'サ', 'シ', 'ス', 'セ', 'ソ', 'ザ', 'ジ', 'ズ', 'ゼ', 'ゾ', 'タ', 'チ', 'ツ', 'テ', 'ト',
  'ダ', 'ヂ', 'ヅ', 'デ', 'ド', 'ナ', 'ニ', 'ヌ', 'ネ', 'ノ', 'ハ', 'ヒ', 'フ', 'ヘ', 'ホ',
  'バ', 'ビ', 'ブ', 'ベ', 'ボ', 'パ', 'ピ', 'プ', 'ペ', 'ポ', 'マ', 'ミ', 'ム', 'メ', 'モ',
  'ヤ', 'ユ', 'ヨ', 'ラ', 'リ', 'ル', 'レ', 'ロ', 'ワ', 'ヲ', 'ン', 'ー',
];

/** 字符串是否全为假名（平假名 + 片假名 + 长音符）*/
function isAllKana(str: string): boolean {
  return /^[\u3040-\u309f\u30a0-\u30ff\u30fc\uff70]+$/.test(str);
}

/** 字符串是否全为片假名（含长音符）*/
function isAllKatakana(str: string): boolean {
  return /^[\u30a0-\u30ff\u30fc\uff70]+$/.test(str);
}

/**
 * 取适合拼写题的假名拼写：
 * 1. reading 为纯假名 → 直接返回
 * 2. word 为纯片假名 → 用 word 本身
 * 3. 其他（含罗马字等）→ 返回 null，不出拼写题
 */
function pickKanaSpelling(detail: VocabFullDetail): string | null {
  const reading = detail.reading.trim();
  if (reading.length > 0 && isAllKana(reading)) {
    return reading;
  }
  const word = detail.word.trim();
  if (isAllKatakana(word)) {
    return word;
  }
  return null;
}

export async function handleCreateReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: ReviewSessionCreateRequest;
  try {
    body = await request.json<ReviewSessionCreateRequest>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid review session payload');
  }

  const limit = clampSessionLimit(body.limit);
  if (body.kind === 'kana') {
    return createOrResumeKanaReviewSession(request, env, auth, limit);
  }
  if (body.kind !== 'word') {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid review session kind');
  }
  return createOrResumeWordReviewSession(request, env, auth, limit);
}

export async function handleCompleteReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
  sessionId: string,
): Promise<Response> {
  let body: ReviewSessionCompleteRequest;
  try {
    body = await request.json<ReviewSessionCompleteRequest>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid review session payload');
  }

  const existing = await getReviewSessionById(env, auth.sub, sessionId);
  if (!existing) {
    return errorResponse(404, 'SESSION_NOT_FOUND', 'Review session not found');
  }

  let appliedCount = 0;
  let rpcResponse: Response;
  try {
    if (existing.session_kind === 'kana') {
      const kanaStates = buildKanaReviewStateUpserts(existing.items, body.results ?? []);
      appliedCount = kanaStates.length;
      rpcResponse = await supabaseRpc(
        env,
        'complete_kana_review_session',
        {
          p_user_id: auth.sub,
          p_session_id: sessionId,
          p_kana_states: kanaStates,
        },
      );
    } else {
      const wordStates = buildWordReviewStateUpserts(existing.items, body.results ?? []);
      appliedCount = wordStates.length;
      rpcResponse = await supabaseRpc(
        env,
        'complete_word_review_session',
        {
          p_user_id: auth.sub,
          p_session_id: sessionId,
          p_word_states: wordStates,
        },
      );
    }
  } catch (error) {
    return errorResponse(
      400,
      'BAD_REQUEST',
      error instanceof Error ? error.message : 'Invalid review results payload',
    );
  }

  if (!rpcResponse.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to complete review session');
  }

  const payload = await rpcResponse.json<Record<string, unknown>>();
  if (payload.applied !== true) {
    if (payload.reason === 'STALE_SESSION') {
      return errorResponse(409, 'STALE_SESSION', 'Review session is stale');
    }
    return errorResponse(500, 'DB_ERROR', 'Failed to complete review session');
  }

  return jsonResponse(
    {
      data: {
        session_id: sessionId,
        status: 'completed',
        applied_count: appliedCount,
      },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleAbandonReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
  sessionId: string,
): Promise<Response> {
  const existing = await getReviewSessionById(env, auth.sub, sessionId);
  if (!existing) {
    return errorResponse(404, 'SESSION_NOT_FOUND', 'Review session not found');
  }

  if (existing.status !== 'active') {
    return jsonResponse(
      {
        data: {
          session_id: existing.id,
          status: existing.status,
        },
        meta: { server_time: new Date().toISOString() },
      },
      corsHeaders(request),
    );
  }

  await abandonReviewSession(env, auth.sub, existing.session_kind, sessionId);

  return jsonResponse(
    {
      data: {
        session_id: sessionId,
        status: 'abandoned',
      },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleUpsertWordStates(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: WordStateRequestPayload | { states?: WordStateRequestPayload[] };
  try {
    body = await request.json<WordStateRequestPayload | { states?: WordStateRequestPayload[] }>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  const inputStates = Array.isArray((body as { states?: WordStateRequestPayload[] }).states)
    ? (body as { states?: WordStateRequestPayload[] }).states ?? []
    : [body as WordStateRequestPayload];
  const states = inputStates
    .map((state) => normalizeWordStatePayload(state, auth.sub))
    .filter((state): state is Record<string, unknown> => state != null);

  if (states.length === 0) {
    return errorResponse(400, 'BAD_REQUEST', 'No valid word states provided');
  }

  const response = await supabaseFetch(
    env,
    '/user_word_states',
    { on_conflict: 'user_id,word_id,book_id' },
    {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
      body: states,
    },
  );
  if (!response.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to upsert word states');
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

async function createOrResumeWordReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
  limit: number,
): Promise<Response> {
  const activeSession = await getActiveReviewSession(env, auth.sub, 'word');
  if (activeSession) {
    if (isSessionExpired(activeSession.created_at)) {
      await abandonReviewSession(env, auth.sub, 'word', activeSession.id);
    } else {
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
  }

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

async function createOrResumeKanaReviewSession(
  request: Request,
  env: Env,
  auth: AuthPayload,
  limit: number,
): Promise<Response> {
  const activeSession = await getActiveReviewSession(env, auth.sub, 'kana');
  if (activeSession) {
    if (isSessionExpired(activeSession.created_at)) {
      await abandonReviewSession(env, auth.sub, 'kana', activeSession.id);
    } else {
      return jsonResponse(
        {
          data: toStoredReviewSession<KanaReviewSessionItem>(activeSession),
          meta: {
            count: activeSession.items.length,
            resumed: true,
            server_time: new Date().toISOString(),
          },
        },
        corsHeaders(request),
      );
    }
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const [stateResp, lettersResp] = await Promise.all([
    supabaseFetch(env, '/user_kana_states', {
      select: '*',
      user_id: `eq.${auth.sub}`,
      learning_status: 'eq.1',
      or: `(next_review_at.is.null,next_review_at.lte.${nowSeconds})`,
      order: 'next_review_at.asc.nullsfirst',
      limit: String(limit),
    }),
    supabaseFetch(env, '/kana_letters', {
      select: '*',
      limit: '200',
    }),
  ]);

  if (!stateResp.ok || !lettersResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch due kana reviews');
  }

  const stateRows = (await stateResp.json()) as UserKanaStateRow[];
  if (stateRows.length === 0) {
    return jsonResponse(
      {
        data: emptyReviewSession<KanaReviewSessionItem>(),
        meta: {
          count: 0,
          resumed: false,
          server_time: new Date().toISOString(),
        },
      },
      corsHeaders(request),
    );
  }

  const letters = (await lettersResp.json()) as KanaLetterRow[];
  letters.sort(
    (left, right) =>
      (left.display_order ?? Number.MAX_SAFE_INTEGER) -
          (right.display_order ?? Number.MAX_SAFE_INTEGER) ||
      left.id - right.id,
  );
  const letterById = new Map<number, KanaLetterRow>();
  for (const letter of letters) {
    letterById.set(letter.id, letter);
  }

  const items = stateRows
    .map((row) => buildKanaReviewItem(row, letterById, letters, auth.sub))
    .filter((item): item is KanaReviewSessionItem => item != null);

  if (items.length === 0) {
    return jsonResponse(
      {
        data: emptyReviewSession<KanaReviewSessionItem>(),
        meta: { count: 0, resumed: false, server_time: new Date().toISOString() },
      },
      corsHeaders(request),
    );
  }

  const createdSession = await createReviewSession(env, auth.sub, 'kana', items);

  return jsonResponse(
    {
      data: toStoredReviewSession<KanaReviewSessionItem>(createdSession),
      meta: { count: items.length, resumed: false, server_time: new Date().toISOString() },
    },
    corsHeaders(request),
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
  const kanaSpelling = pickKanaSpelling(detail);
  const availableTypes = collectWordReviewTypes(meaning, reading, kanaSpelling, detail, row);
  if (availableTypes.length === 0) {
    return null;
  }

  const questionType = chooseWordReviewType(auth.sub, row, detail.word, availableTypes);
  const clozeSentence =
    questionType === 'cloze_test'
      ? buildClozeSentence(detail.word, detail.reading, detail.examples)
      : null;

  // meaning_to_spelling 题的 reading 字段必须是假名，不能是 romaji
  const itemReading = questionType === 'meaning_to_spelling' ? kanaSpelling : reading;

  return {
    word_state: row,
    word_detail: detail,
    question_type: questionType,
    audio_source: detail.has_audio
      ? new URL(`/api/v1/audio/words/${row.word_id}`, request.url).toString()
      : null,
    meaning,
    reading: itemReading,
    options: buildWordReviewOptions(questionType, meaning, reading, detail, kanaSpelling, distractorPool, sessionDetails),
    cloze_sentence: clozeSentence,
  };
}

function buildWordReviewOptions(
  questionType: WordReviewQuestionType,
  meaning: string | null,
  reading: string | null,
  detail: VocabFullDetail,
  kanaSpelling: string | null,
  distractorPool: VocabWord[],
  sessionDetails: VocabFullDetail[],
): string[] {
  if (questionType === 'meaning_to_spelling') {
    const spelling = kanaSpelling ?? '';
    const correctChars = spelling.split('').filter((c) => c.length > 0);
    const answerSet = new Set(correctChars);
    const pool = isAllKatakana(spelling) ? katakanaOptionPool : kanaOptionPool;
    const distractors = shuffleArray(pool.filter((c) => !answerSet.has(c))).slice(0, 5);
    return shuffleArray(uniqueStrings([...correctChars, ...distractors]));
  }

  // cloze_test：选项为单词形式（目标词 + 3 个干扰词）
  if (questionType === 'cloze_test') {
    const options: string[] = [detail.word];
    for (const candidate of distractorPool) {
      if (candidate.word && !options.includes(candidate.word)) {
        options.push(candidate.word);
      }
      if (options.length >= 4) break;
    }
    for (const d of sessionDetails) {
      if (d.word !== detail.word && !options.includes(d.word)) {
        options.push(d.word);
      }
      if (options.length >= 4) break;
    }
    return shuffleArray(options.slice(0, 4));
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
  kanaSpelling: string | null,
  detail: VocabFullDetail,
  row: UserWordStateRow,
): WordReviewQuestionType[] {
  const result: WordReviewQuestionType[] = [];
  if (meaning) {
    result.push('word_to_meaning');
    if (kanaSpelling) {
      result.push('meaning_to_spelling');
    }
  }
  if (reading) {
    result.push('kanji_to_reading');
  }
  // cloze_test 仅在复习次数 >= 2 且有可用例句时提供
  if (row.total_reviews >= 2 && detail.examples.length > 0) {
    const hasCloze = detail.examples.some(
      (ex) => ex.japanese.includes(detail.word) || (detail.reading && ex.japanese.includes(detail.reading)),
    );
    if (hasCloze) {
      result.push('cloze_test');
    }
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
  // total_reviews >= 2 时有 30% 几率选填空题（如果可用）
  if (bucket < 3 && available.includes('cloze_test')) {
    return 'cloze_test';
  }
  if (
    bucket < 6 &&
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

function buildClozeSentence(word: string, reading: string, examples: VocabExample[]): string | null {
  for (const example of examples) {
    const japanese = example.japanese;
    if (word.length > 0 && japanese.includes(word)) {
      return japanese.replace(word, '___');
    }
    if (reading.length > 0 && japanese.includes(reading)) {
      return japanese.replace(reading, '___');
    }
  }
  return null;
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
  sessionId: string,
): Promise<ReviewSessionRow | null> {
  const response = await supabaseFetch(env, '/user_review_sessions', {
    select: '*',
    id: `eq.${sessionId}`,
    user_id: `eq.${userId}`,
    limit: '1',
  });

  if (!response.ok) {
    throw new Error('Failed to fetch review session by id');
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

async function abandonReviewSession(
  env: Env,
  userId: string,
  kind: ReviewSessionKind,
  sessionId: string,
): Promise<void> {
  const response = await supabaseFetch(
    env,
    '/user_review_sessions',
    {
      id: `eq.${sessionId}`,
      user_id: `eq.${userId}`,
      session_kind: `eq.${kind}`,
      status: 'eq.active',
    },
    {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: {
        status: 'abandoned',
        closed_at: new Date().toISOString(),
      },
    },
  );

  if (!response.ok) {
    throw new Error(`Failed to abandon ${kind} review session`);
  }
}

function buildWordReviewStateUpserts(
  rawItems: unknown[],
  rawResults: Array<WordReviewResultPayload | KanaReviewResultPayload>,
): WordStateUpsertPayload[] {
  if (!Array.isArray(rawResults)) {
    throw new Error('results must be an array');
  }

  const statesByKey = new Map<string, UserWordStateRow>();
  const keysByWordId = new Map<string, string[]>();

  for (const rawItem of rawItems) {
    const item = rawItem as WordReviewSessionItem;
    if (!item?.word_state?.word_id || !item.word_state.book_id) {
      continue;
    }
    const key = buildWordStateKey(item.word_state.word_id, item.word_state.book_id);
    statesByKey.set(key, { ...item.word_state });
    const existingKeys = keysByWordId.get(item.word_state.word_id) ?? [];
    existingKeys.push(key);
    keysByWordId.set(item.word_state.word_id, existingKeys);
  }

  const touchedKeys = new Set<string>();

  for (const result of rawResults) {
    const key = resolveWordReviewResultKey(result, keysByWordId);
    const current = statesByKey.get(key);
    if (!current) {
      throw new Error('Review result item is not in session');
    }

    const rating = normalizeReviewRating(result.rating);
    const nextState = applySm2Review(current, rating);
    statesByKey.set(key, nextState);
    touchedKeys.add(key);
  }

  return Array.from(touchedKeys).map((key) => toWordStateUpsertPayload(statesByKey.get(key)!));
}

function buildKanaReviewStateUpserts(
  rawItems: unknown[],
  rawResults: Array<WordReviewResultPayload | KanaReviewResultPayload>,
): UserKanaStateRow[] {
  if (!Array.isArray(rawResults)) {
    throw new Error('results must be an array');
  }

  const statesByKanaId = new Map<number, UserKanaStateRow>();
  for (const rawItem of rawItems) {
    const item = rawItem as KanaReviewSessionItem;
    if (!item?.learning_state?.kana_id) {
      continue;
    }
    statesByKanaId.set(item.learning_state.kana_id, { ...item.learning_state });
  }

  const touchedKanaIds = new Set<number>();
  for (const rawResult of rawResults) {
    const result = rawResult as KanaReviewResultPayload;
    const kanaId = typeof result.kana_id === 'number' ? result.kana_id : 0;
    if (kanaId <= 0) {
      throw new Error('results[].kana_id is required');
    }
    const current = statesByKanaId.get(kanaId);
    if (!current) {
      throw new Error('Review result item is not in session');
    }
    const rating = normalizeReviewRating(result.rating);
    const nextState = applySm2ReviewToKana(current, rating);
    statesByKanaId.set(kanaId, nextState);
    touchedKanaIds.add(kanaId);
  }

  return Array.from(touchedKanaIds)
    .map((kanaId) => statesByKanaId.get(kanaId))
    .filter((state): state is UserKanaStateRow => state != null);
}

function resolveWordReviewResultKey(
  result: WordReviewResultPayload,
  keysByWordId: Map<string, string[]>,
): string {
  const wordId = typeof result.word_id === 'string' ? result.word_id.trim() : '';
  if (wordId.length === 0) {
    throw new Error('results[].word_id is required');
  }

  const explicitBookId = typeof result.book_id === 'string' ? result.book_id.trim() : '';
  if (explicitBookId.length > 0) {
    return buildWordStateKey(wordId, explicitBookId);
  }

  const matchingKeys = keysByWordId.get(wordId) ?? [];
  if (matchingKeys.length !== 1) {
    throw new Error('results[].book_id is required for duplicated word_id');
  }
  return matchingKeys[0];
}

function normalizeReviewRating(rating: ReviewRatingValue | undefined): ReviewRatingValue {
  switch (rating) {
    case 'again':
    case 'hard':
    case 'good':
    case 'easy':
      return rating;
    default:
      throw new Error('results[].rating is invalid');
  }
}

function applySm2Review(
  state: UserWordStateRow,
  rating: ReviewRatingValue,
): UserWordStateRow {
  const now = new Date();
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const reviews = state.total_reviews ?? 0;
  const baseInterval = state.interval ?? 0;
  const baseEaseFactor = state.ease_factor ?? 2.5;

  let newInterval: number;
  let newEaseFactor = baseEaseFactor;

  const quality = reviewRatingToQuality(rating);
  if (quality < 3) {
    newInterval = 0;
    newEaseFactor = Math.max(1.3, baseEaseFactor - 0.20);
  } else {
    const effectiveInterval = baseInterval <= 0 ? 1 : baseInterval;
    if (reviews === 0) {
      newInterval = 6;
    } else {
      newInterval = Math.round(effectiveInterval * baseEaseFactor);
    }

    if (newInterval < 1) {
      newInterval = 1;
    }

    newEaseFactor = baseEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEaseFactor = Math.max(1.3, newEaseFactor);
  }

  if (rating === 'hard' && reviews > 1) {
    newInterval = Math.round(baseInterval * 1.2);
    newEaseFactor = Math.max(1.3, baseEaseFactor - 0.15);
  }

  if (rating === 'easy') {
    newEaseFactor += 0.15;
    if (reviews > 1) {
      newInterval = Math.round(baseInterval * baseEaseFactor * 1.3);
    }
  }

  const nextReviewAt = rating === 'again'
    ? nowSeconds + 60
    : nowSeconds + (Math.ceil(newInterval) * 86400);

  return {
    ...state,
    next_review_at: nextReviewAt,
    last_reviewed_at: nowSeconds,
    interval: Math.round(newInterval),
    ease_factor: newEaseFactor,
    stability: 0,
    difficulty: 0,
    streak: isCorrectReviewRating(rating) ? state.streak + 1 : 0,
    total_reviews: state.total_reviews + 1,
    fail_count: state.fail_count + (isCorrectReviewRating(rating) ? 0 : 1),
    updated_at: now.toISOString(),
  };
}

function applySm2ReviewToKana(
  state: UserKanaStateRow,
  rating: ReviewRatingValue,
): UserKanaStateRow {
  const now = new Date();
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const reviews = state.total_reviews ?? 0;
  const baseInterval = state.interval ?? 0;
  const baseEaseFactor = state.ease_factor ?? 2.5;

  let newInterval: number;
  let newEaseFactor = baseEaseFactor;

  const quality = reviewRatingToQuality(rating);
  if (quality < 3) {
    newInterval = 0;
    newEaseFactor = Math.max(1.3, baseEaseFactor - 0.20);
  } else {
    const effectiveInterval = baseInterval <= 0 ? 1 : baseInterval;
    if (reviews === 0) {
      newInterval = 6;
    } else {
      newInterval = Math.round(effectiveInterval * baseEaseFactor);
    }

    if (newInterval < 1) {
      newInterval = 1;
    }

    newEaseFactor = baseEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEaseFactor = Math.max(1.3, newEaseFactor);
  }

  if (rating === 'hard' && reviews > 1) {
    newInterval = Math.round(baseInterval * 1.2);
    newEaseFactor = Math.max(1.3, baseEaseFactor - 0.15);
  }

  if (rating === 'easy') {
    newEaseFactor += 0.15;
    if (reviews > 1) {
      newInterval = Math.round(baseInterval * baseEaseFactor * 1.3);
    }
  }

  const nextReviewAt = rating === 'again'
    ? nowSeconds + 60
    : nowSeconds + (Math.ceil(newInterval) * 86400);

  return {
    ...state,
    next_review_at: nextReviewAt,
    last_reviewed_at: nowSeconds,
    interval: Math.round(newInterval),
    ease_factor: newEaseFactor,
    stability: 0,
    difficulty: 0,
    streak: isCorrectReviewRating(rating) ? state.streak + 1 : 0,
    total_reviews: state.total_reviews + 1,
    fail_count: state.fail_count + (isCorrectReviewRating(rating) ? 0 : 1),
    updated_at: now.toISOString(),
  };
}

function buildKanaReviewItem(
  row: UserKanaStateRow,
  letterById: Map<number, KanaLetterRow>,
  allLetters: KanaLetterRow[],
  userId: string,
): KanaReviewSessionItem | null {
  const letter = letterById.get(row.kana_id);
  if (!letter) {
    return null;
  }

  const questionType = chooseKanaReviewType(letter, userId);
  const counterpartLetter = resolveKanaCounterpart(letter, allLetters);

  return {
    kana_letter: letter,
    learning_state: row,
    audio_filename: null,
    question_type: questionType,
    options: buildKanaReviewOptions(questionType, letter, counterpartLetter, allLetters),
    counterpart_letter: counterpartLetter,
  };
}

function chooseKanaReviewType(
  letter: KanaLetterRow,
  userId: string,
): KanaReviewQuestionType {
  const seed = Math.abs(simpleHash(`${userId}:${letter.id}`)) % 3;
  if (letter.script_kind === 'hiragana') {
    return seed === 0
      ? 'hiragana_to_romaji'
      : seed === 1
        ? 'romaji_to_hiragana'
        : 'hiragana_to_katakana';
  }

  return seed === 0
    ? 'katakana_to_romaji'
    : seed === 1
      ? 'romaji_to_katakana'
      : 'katakana_to_hiragana';
}

function buildKanaReviewOptions(
  questionType: KanaReviewQuestionType,
  letter: KanaLetterRow,
  counterpart: KanaLetterRow | null,
  allLetters: KanaLetterRow[],
): string[] {
  const otherLetters = allLetters.filter((item) => item.id !== letter.id);
  const options: string[] = [];

  switch (questionType) {
    case 'hiragana_to_romaji':
    case 'katakana_to_romaji':
      options.push(letter.romaji);
      for (const item of otherLetters) {
        if (!options.includes(item.romaji)) {
          options.push(item.romaji);
        }
        if (options.length >= 4) {
          break;
        }
      }
      break;
    case 'romaji_to_hiragana':
    case 'katakana_to_hiragana':
      options.push(
        questionType === 'romaji_to_hiragana'
          ? letter.kana_char
          : counterpart?.kana_char ?? letter.kana_char,
      );
      for (const item of otherLetters) {
        if (item.script_kind === 'hiragana' && !options.includes(item.kana_char)) {
          options.push(item.kana_char);
        }
        if (options.length >= 4) {
          break;
        }
      }
      break;
    case 'romaji_to_katakana':
    case 'hiragana_to_katakana':
      options.push(
        questionType === 'romaji_to_katakana'
          ? letter.kana_char
          : counterpart?.kana_char ?? letter.kana_char,
      );
      for (const item of otherLetters) {
        if (item.script_kind === 'katakana' && !options.includes(item.kana_char)) {
          options.push(item.kana_char);
        }
        if (options.length >= 4) {
          break;
        }
      }
      break;
  }

  if (options.length < 4) {
    for (const item of otherLetters) {
      if (!options.includes(item.kana_char)) {
        options.push(item.kana_char);
      }
      if (options.length >= 4) {
        break;
      }
    }
  }

  return shuffleArray(options.slice(0, 4));
}

function resolveKanaCounterpart(
  letter: KanaLetterRow,
  allLetters: KanaLetterRow[],
): KanaLetterRow | null {
  if (!letter.pair_group_id) {
    return null;
  }

  const targetKind = letter.script_kind === 'hiragana' ? 'katakana' : 'hiragana';
  for (const candidate of allLetters) {
    if (candidate.pair_group_id === letter.pair_group_id && candidate.script_kind === targetKind) {
      return candidate;
    }
  }
  return null;
}

function reviewRatingToQuality(rating: ReviewRatingValue): number {
  switch (rating) {
    case 'again':
      return 0;
    case 'hard':
      return 3;
    case 'good':
      return 4;
    case 'easy':
      return 5;
  }
}

function isCorrectReviewRating(rating: ReviewRatingValue): boolean {
  return rating !== 'again';
}

function toWordStateUpsertPayload(state: UserWordStateRow): WordStateUpsertPayload {
  return {
    word_id: state.word_id,
    book_id: state.book_id,
    user_state: state.user_state,
    next_review_at: state.next_review_at,
    last_reviewed_at: state.last_reviewed_at,
    first_learned_at: state.first_learned_at,
    interval: state.interval,
    ease_factor: state.ease_factor,
    stability: state.stability ?? 0,
    difficulty: state.difficulty ?? 0,
    streak: state.streak,
    total_reviews: state.total_reviews,
    fail_count: state.fail_count,
    created_at: toEpochSeconds(state.created_at),
    updated_at: toEpochSeconds(state.updated_at),
    version: 1,
  };
}

function buildWordStateKey(wordId: string, bookId: string): string {
  return `${bookId}::${wordId}`;
}

function normalizeWordStatePayload(
  state: WordStateRequestPayload,
  userId: string,
): Record<string, unknown> | null {
  const wordId = state.word_id?.trim();
  const bookId = state.book_id?.trim();
  const userState = toNullableInteger(state.user_state);
  if (!wordId || !bookId || userState == null) {
    return null;
  }

  const payload: Record<string, unknown> = {
    user_id: userId,
    word_id: wordId,
    book_id: bookId,
    user_state: userState,
  };

  const nextReviewAt = toNullableInteger(state.next_review_at);
  const lastReviewedAt = toNullableInteger(state.last_reviewed_at);
  const firstLearnedAt = toNullableInteger(state.first_learned_at);
  const interval = toNullableInteger(state.interval);
  const easeFactor = toNullableFloat(state.ease_factor);
  const stability = toNullableFloat(state.stability);
  const difficulty = toNullableFloat(state.difficulty);
  const streak = toNullableInteger(state.streak);
  const totalReviews = toNullableInteger(state.total_reviews);
  const failCount = toNullableInteger(state.fail_count);
  const version = toNullableInteger(state.version);

  if (nextReviewAt != null) payload['next_review_at'] = nextReviewAt;
  if (lastReviewedAt != null) payload['last_reviewed_at'] = lastReviewedAt;
  if (firstLearnedAt != null) payload['first_learned_at'] = firstLearnedAt;
  if (interval != null) payload['interval'] = interval;
  if (easeFactor != null) payload['ease_factor'] = easeFactor;
  if (stability != null) payload['stability'] = stability;
  if (difficulty != null) payload['difficulty'] = difficulty;
  if (streak != null) payload['streak'] = streak;
  if (totalReviews != null) payload['total_reviews'] = totalReviews;
  if (failCount != null) payload['fail_count'] = failCount;
  if (version != null) payload['version'] = version;

  return payload;
}

function toNullableInteger(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function toNullableFloat(value: unknown): number | null {
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

function toEpochSeconds(value: string): number {
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    return Math.floor(Date.now() / 1000);
  }
  return Math.floor(parsed / 1000);
}

function isSessionExpired(createdAt: string): boolean {
  const createdAtMs = Date.parse(createdAt);
  if (Number.isNaN(createdAtMs)) {
    return false;
  }
  return (Date.now() - createdAtMs) > REVIEW_SESSION_TTL_MS;
}

function clampSessionLimit(raw: number | undefined): number {
  if (typeof raw !== 'number' || Number.isNaN(raw)) {
    return 20;
  }
  return Math.min(Math.max(Math.trunc(raw), 1), MAX_SESSION_LIMIT);
}

function emptyReviewSession<TItem>(): ReviewSessionEnvelope<TItem> {
  return {
    session_id: null,
    current_index: 0,
    items: [],
  };
}

function toStoredReviewSession<TItem>(
  session: ReviewSessionRow,
): ReviewSessionEnvelope<TItem> {
  return {
    session_id: session.id,
    current_index: session.current_index,
    items: Array.isArray(session.items) ? (session.items as TItem[]) : [],
  };
}