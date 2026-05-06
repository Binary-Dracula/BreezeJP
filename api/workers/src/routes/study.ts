import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env, ReviewSessionEnvelope, ReviewSessionPhase, ReviewSessionStatus, ReviewSessionUpdateRequest, VocabExample, VocabFullDetail, VocabWord } from '../types';
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
  /** cloze_test 题型专用：目标单词已替换为 ___ 的例句 */
  cloze_sentence?: string | null;
};

type WordReviewQuestionType =
  | 'word_to_meaning'
  | 'audio_to_meaning'
  | 'kanji_to_reading'
  | 'meaning_to_spelling'
  | 'cloze_test';

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