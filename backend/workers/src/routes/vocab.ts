import { Env, VocabBook, VocabWord, VocabFullDetail, VocabExample, VocabWordDetail } from '../types';
import { corsHeaders } from '../middleware/cors';
import { supabaseFetch, jsonResponse, errorResponse } from '../utils/supabase';

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

  return jsonResponse({
    data: result,
    meta: { has_more: hasMore },
  }, corsHeaders(request));
}

/**
 * 批量获取词条完整详情（words + word_details + word_examples）
 */
async function fetchFullDetailsBatch(
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
 * GET /api/v1/books
 * 获取所有书籍列表
 */
export async function handleBookList(
  request: Request,
  env: Env,
): Promise<Response> {
  const resp = await supabaseFetch(env, '/books', {
    select: '*',
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

