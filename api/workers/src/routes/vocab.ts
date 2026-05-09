import { Env, VocabBook, VocabWord, VocabFullDetail, VocabExample, VocabWordDetail } from '../types';
import { corsHeaders } from '../middleware/cors';
import { supabaseFetch, jsonResponse, errorResponse } from '../utils/supabase';
import { AuthPayload } from '../middleware/auth';

type LessonRow = {
  id: string;
  lesson_number: number;
};

type LessonWordMapRow = {
  word_id: string;
  lesson_id: string | null;
  sort_order: number;
};

/**
 * GET /api/v1/books/:bookId/next-words?after_sort=<N>&limit=<M>
 * 按 book_sort_order 顺序取下一批新词（含完整详情）
 * after_sort: 上一个已学词的 book_sort_order，0 表示从头开始
 * limit: 最多返回数量，默认 10，最大 50
 */
export async function handleNextWords(
  request: Request,
  env: Env,
  bookId: string
): Promise<Response> {
  const url = new URL(request.url);
  const afterSort = parseInt(url.searchParams.get('after_sort') ?? '0', 10);
  const limitRaw = parseInt(url.searchParams.get('limit') ?? '10', 10);
  const limit = Math.min(Math.max(limitRaw, 1), 50);

  const bookResp = await supabaseFetch(env, '/books', {
    select: 'id,is_available',
    id: `eq.${bookId}`,
    limit: '1',
  });

  if (!bookResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to validate book state');
  }

  const books = (await bookResp.json()) as Array<Pick<VocabBook, 'id' | 'is_available'>>;
  const book = books[0];
  if (!book) {
    return errorResponse(404, 'BOOK_NOT_FOUND', 'Book not found');
  }

  if (!book.is_available) {
    return errorResponse(409, 'BOOK_UNAVAILABLE', 'Book is no longer available');
  }

  // 云端当前没有 book_sort_order，按 lesson_number + lesson 内 sort_order 现场合成稳定顺序。
  const sequenceRows = await fetchBookSequenceRows(env, bookId);
  const nextRows = sequenceRows
    .filter(row => row.book_sort_order > afterSort)
    .slice(0, limit);

  if (nextRows.length === 0) {
    return jsonResponse({ data: [], meta: { has_more: false } }, corsHeaders(request));
  }

  // 2. 批量拉取完整词条详情
  const wordIds = nextRows.map(m => m.word_id);
  const fullDetails = await fetchFullDetailsBatch(env, wordIds);

  // 3. 按 book_sort_order 排列并附加排序信息
  const result = nextRows.map(m => ({
    book_sort_order: m.book_sort_order,
    ...(fullDetails.get(m.word_id) ?? { id: m.word_id }),
  }));
  const hasMore = sequenceRows.length > afterSort + nextRows.length;
  const nextCursor = nextRows.length > 0
    ? nextRows[nextRows.length - 1].book_sort_order
    : afterSort;

  return jsonResponse({
    data: result,
    meta: {
      has_more: hasMore,
      total_words: sequenceRows.length,
      next_cursor: nextCursor,
    },
  }, corsHeaders(request));
}

/**
 * GET /api/v1/learn/books/:bookId/next?limit=<M>
 * 服务端根据云端 user_book_progress.current_sort_cursor 决定下一批学习词。
 */
export async function handleUserNextWords(
  request: Request,
  env: Env,
  auth: AuthPayload,
  bookId: string
): Promise<Response> {
  const url = new URL(request.url);
  const limitRaw = parseInt(url.searchParams.get('limit') ?? '10', 10);
  const limit = Math.min(Math.max(limitRaw, 1), 50);

  const bookResp = await supabaseFetch(env, '/books', {
    select: 'id,is_available',
    id: `eq.${bookId}`,
    limit: '1',
  });

  if (!bookResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to validate book state');
  }

  const books = (await bookResp.json()) as Array<Pick<VocabBook, 'id' | 'is_available'>>;
  const book = books[0];
  if (!book) {
    return errorResponse(404, 'BOOK_NOT_FOUND', 'Book not found');
  }

  if (!book.is_available) {
    return errorResponse(409, 'BOOK_UNAVAILABLE', 'Book is no longer available');
  }

  const progressResp = await supabaseFetch(env, '/user_book_progress', {
    select: 'current_sort_cursor',
    user_id: `eq.${auth.sub}`,
    book_id: `eq.${bookId}`,
    limit: '1',
  });

  if (!progressResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to read cloud book progress');
  }

  const progressRows = (await progressResp.json()) as Array<{ current_sort_cursor: number }>;
  const currentCursor = progressRows[0]?.current_sort_cursor ?? 0;

  // 并行拉取书籍单词顺序表 + 用户已有学习记录的 word_id（任意 state 均排除）
  const [sequenceRows, learnedIds] = await Promise.all([
    fetchBookSequenceRows(env, bookId),
    fetchUserLearnedWordIds(env, auth.sub, bookId),
  ]);

  const nextRows = sequenceRows
    .filter(row => row.book_sort_order > currentCursor && !learnedIds.has(row.word_id))
    .slice(0, limit);

  if (nextRows.length === 0) {
    return jsonResponse({
      data: [],
      meta: {
        has_more: false,
        total_words: sequenceRows.length,
        next_cursor: currentCursor,
      },
    }, corsHeaders(request));
  }

  const wordIds = nextRows.map(m => m.word_id);
  const fullDetails = await fetchFullDetailsBatch(env, wordIds);
  const result = nextRows.map(m => ({
    book_sort_order: m.book_sort_order,
    ...(fullDetails.get(m.word_id) ?? { id: m.word_id }),
  }));
  const nextCursor = nextRows[nextRows.length - 1].book_sort_order;
  const hasMore = sequenceRows.length > nextCursor;

  return jsonResponse({
    data: result,
    meta: {
      has_more: hasMore,
      total_words: sequenceRows.length,
      next_cursor: nextCursor,
      current_cursor: currentCursor,
    },
  }, corsHeaders(request));
}

/**
 * 获取用户在某本书中已有学习记录（任意 state）的 word_id 集合。
 * 用于 handleUserNextWords 过滤，防止已学词再次出现在新批次里。
 */
async function fetchUserLearnedWordIds(
  env: Env,
  userId: string,
  bookId: string
): Promise<Set<string>> {
  const resp = await supabaseFetch(env, '/user_word_states', {
    select: 'word_id',
    user_id: `eq.${userId}`,
    book_id: `eq.${bookId}`,
    limit: '5000',
  });
  if (!resp.ok) return new Set();
  const rows = (await resp.json()) as Array<{ word_id: string }>;
  return new Set(rows.map(r => r.word_id));
}

/**
 * 批量获取词条完整详情（words + word_details + word_examples）
 */
export async function fetchFullDetailsBatch(
  env: Env,
  wordIds: string[]
): Promise<Map<string, VocabFullDetail>> {
  const idFilter = `in.(${wordIds.join(',')})`;

  // 并行请求三张表
  const [wordsResp, detailsResp, examplesResp] = await Promise.all([
    supabaseFetch(env, '/words', { select: '*', id: idFilter }),
    supabaseFetch(env, '/word_details', { select: '*', word_id: idFilter }),
    supabaseFetch(env, '/word_examples', { select: '*', word_id: idFilter, order: 'sort_order.asc' }),
  ]);

  const wordsData = wordsResp.ok ? (await wordsResp.json()) as VocabWord[] : [];
  const detailsData = detailsResp.ok ? (await detailsResp.json()) as VocabWordDetail[] : [];
  const examplesData = examplesResp.ok ? (await examplesResp.json()) as VocabExample[] : [];

  // 索引化
  const detailMap = new Map(detailsData.map(d => [d.word_id, d]));
  const exampleMap = new Map<string, VocabExample[]>();
  for (const ex of examplesData) {
    const arr = exampleMap.get(ex.word_id) ?? [];
    arr.push(ex);
    exampleMap.set(ex.word_id, arr);
  }

  // 组装完整详情
  const result = new Map<string, VocabFullDetail>();
  for (const word of wordsData) {
    const detail = detailMap.get(word.id);
    let richContent: VocabWordDetail['rich_content'] = { meanings: [] };
    if (detail) {
      richContent = { ...detail.rich_content };
      if (richContent._source_meta) {
        delete richContent._source_meta;
      }
    }

    result.set(word.id, {
      ...word,
      rich_content: richContent,
      examples: exampleMap.get(word.id) ?? [],
    });
  }

  return result;
}

/**
 * GET /api/v1/words/:id
 * 获取单个词条完整详情。
 */
export async function handleWordDetail(
  request: Request,
  env: Env,
  wordId: string,
): Promise<Response> {
  const details = await fetchFullDetailsBatch(env, [wordId]);
  const detail = details.get(wordId);

  if (!detail) {
    return errorResponse(404, 'WORD_NOT_FOUND', 'Word not found');
  }

  return jsonResponse(
    {
      data: detail,
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

/**
 * GET /api/v1/books
 * 获取所有书籍列表
 */
export async function handleBookList(
  request: Request,
  env: Env,
): Promise<Response> {
  const resp = await supabaseFetch(env, '/books', {
    select: '*',
    is_available: 'eq.true',
    order: 'sort_order.asc'
  });

  if (!resp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch books');
  }

  const books = (await resp.json()) as VocabBook[];
  const booksWithCount = await Promise.all(
    books.map(async (book) => {
      const countResp = await supabaseFetch(env, '/lesson_word_map', {
        select: 'id',
        book_id: `eq.${book.id}`,
        limit: '1',
      });

      if (!countResp.ok) {
        return book;
      }

      const contentRange = countResp.headers.get('content-range');
      const exactCount = parseContentRangeTotal(contentRange);
      return {
        ...book,
        word_count: exactCount ?? book.word_count,
      };
    }),
  );

  return jsonResponse({ data: booksWithCount }, corsHeaders(request));
}

/**
 * GET /api/v1/books/sync?since=<ISO>
 * 增量同步 books 元数据，包含可用状态变更。
 */
export async function handleBookSync(
  request: Request,
  env: Env,
): Promise<Response> {
  const url = new URL(request.url);
  const since = url.searchParams.get('since');
  const serverTime = new Date().toISOString();

  if (!since) {
    return jsonResponse(
      { data: [], meta: { count: 0, server_time: serverTime } },
      corsHeaders(request),
    );
  }

  const resp = await supabaseFetch(env, '/books', {
    select: '*',
    updated_at: `gt.${since}`,
    order: 'updated_at.asc',
    limit: '500',
  });

  if (!resp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch updated books');
  }

  const books = (await resp.json()) as VocabBook[];
  return jsonResponse(
    { data: books, meta: { count: books.length, server_time: serverTime } },
    corsHeaders(request),
  );
}

async function fetchBookSequenceRows(
  env: Env,
  bookId: string,
): Promise<Array<{ word_id: string; book_sort_order: number }>> {
  const [lessonsResp, mapResp] = await Promise.all([
    supabaseFetch(env, '/lessons', {
      select: 'id,lesson_number',
      book_id: `eq.${bookId}`,
      order: 'lesson_number.asc',
      limit: '500',
    }),
    supabaseFetch(env, '/lesson_word_map', {
      select: 'word_id,lesson_id,sort_order',
      book_id: `eq.${bookId}`,
      limit: '5000',
    }),
  ]);

  if (!lessonsResp.ok || !mapResp.ok) {
    throw new Error('Failed to fetch sequence rows');
  }

  const lessons = (await lessonsResp.json()) as LessonRow[];
  const mapRows = (await mapResp.json()) as LessonWordMapRow[];
  const lessonNumberById = new Map(lessons.map(lesson => [lesson.id, lesson.lesson_number]));

  mapRows.sort((a, b) => {
    const lessonNumberA = lessonNumberById.get(a.lesson_id ?? '') ?? 0;
    const lessonNumberB = lessonNumberById.get(b.lesson_id ?? '') ?? 0;
    if (lessonNumberA != lessonNumberB) {
      return lessonNumberA - lessonNumberB;
    }
    if (a.sort_order != b.sort_order) {
      return a.sort_order - b.sort_order;
    }
    return a.word_id.localeCompare(b.word_id);
  });

  return mapRows.map((row, index) => ({
    word_id: row.word_id,
    book_sort_order: index + 1,
  }));
}

/**
 * GET /api/v1/words/sync?since=<ISO>
 * 增量同步：返回 since 时间戳之后更新的所有单词完整数据
 * 客户端根据本地 word_id 是否存在决定是否覆盖
 */
export async function handleWordSync(
  request: Request,
  env: Env,
  _auth: AuthPayload
): Promise<Response> {
  const url = new URL(request.url);
  const since = url.searchParams.get('since');

  if (!since) {
    return jsonResponse(
      { data: [], meta: { count: 0, server_time: new Date().toISOString() } },
      corsHeaders(request)
    );
  }

  // 查询 since 之后有更新的单词（最多 500 条，按 updated_at 升序）
  const wordsResp = await supabaseFetch(env, '/words', {
    select: 'id',
    updated_at: `gt.${since}`,
    order: 'updated_at.asc',
    limit: '500',
  });

  if (!wordsResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch updated words');
  }

  const updatedWords = (await wordsResp.json()) as Array<{ id: string }>;
  const serverTime = new Date().toISOString();

  if (updatedWords.length === 0) {
    return jsonResponse(
      { data: [], meta: { count: 0, server_time: serverTime } },
      corsHeaders(request)
    );
  }

  const wordIds = updatedWords.map(w => w.id);
  const fullDetails = await fetchFullDetailsBatch(env, wordIds);

  const data = wordIds
    .filter(id => fullDetails.has(id))
    .map(id => fullDetails.get(id)!);

  return jsonResponse(
    { data, meta: { count: data.length, server_time: serverTime } },
    corsHeaders(request)
  );
}

function parseContentRangeTotal(contentRange: string | null): number | null {
  if (!contentRange) {
    return null;
  }

  const match = contentRange.match(/\/(\d+)$/);
  if (!match) {
    return null;
  }

  return parseInt(match[1], 10);
}

