import { Env, VocabBook, VocabLesson, VocabWord, VocabFullDetail, VocabExample, VocabWordDetail } from '../types';
import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { supabaseFetch, jsonResponse, errorResponse } from '../utils/supabase';

/**
 * GET /api/v1/books
 * 获取所有书籍列表
 */
export async function handleBookList(
  request: Request,
  env: Env,
  _auth: AuthPayload
): Promise<Response> {
  const resp = await supabaseFetch(env, '/books', {
    select: '*',
    order: 'sort_order.asc'
  });

  if (!resp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch books');
  }

  const books = (await resp.json()) as VocabBook[];
  return jsonResponse({ data: books }, corsHeaders(request));
}

/**
 * GET /api/v1/books/:bookId/lessons
 * 获取某本书的课节列表
 */
export async function handleLessonList(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  bookId: string
): Promise<Response> {
  const resp = await supabaseFetch(env, '/lessons', {
    select: '*',
    book_id: `eq.${bookId}`,
    order: 'lesson_number.asc'
  });

  if (!resp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch lessons');
  }

  const lessons = (await resp.json()) as VocabLesson[];
  return jsonResponse({ data: lessons }, corsHeaders(request));
}

/**
 * GET /api/v1/books/:bookId/words
 * 获取某本书或某课的单词列表（轻量级）
 * 查询参数: lesson_id (可选)
 */
export async function handleVocabWordList(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  bookId: string
): Promise<Response> {
  const url = new URL(request.url);
  const lessonId = url.searchParams.get('lesson_id');

  const params: Record<string, string> = {
    select: 'word_id,sort_order,words(id,word,reading,reading,jlpt_level,part_of_speech,primary_meaning,has_audio)',
    book_id: `eq.${bookId}`,
    order: 'sort_order.asc'
  };

  if (lessonId) {
    params['lesson_id'] = `eq.${lessonId}`;
  }

  const resp = await supabaseFetch(env, '/lesson_word_map', params);

  if (!resp.ok) {
    return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch words from map');
  }

  const mapData = (await resp.json()) as any[];
  // 摊平数据结构
  const words = mapData.map(item => ({
    ...item.words,
    sort_order: item.sort_order
  }));

  return jsonResponse({ data: words }, corsHeaders(request));
}

/**
 * GET /api/v1/words/:id
 * 获取单词完整详情（含 9 维度数据 & 已脱敏）
 */
export async function handleVocabWordDetail(
  request: Request,
  env: Env,
  _auth: AuthPayload,
  id: string
): Promise<Response> {
  // 1. 获取 words 基础信息
  const wordResp = await supabaseFetch(env, '/words', {
    select: '*',
    id: `eq.${id}`,
    limit: '1'
  });

  if (!wordResp.ok) return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch word');
  const wordList = (await wordResp.json()) as VocabWord[];
  if (!wordList.length) return errorResponse(404, 'NOT_FOUND', 'Word not found');
  const word = wordList[0];

  // 2. 获取 word_details (JSONB)
  const detailResp = await supabaseFetch(env, '/word_details', {
    select: 'rich_content',
    word_id: `eq.${id}`,
    limit: '1'
  });

  let richContent: VocabWordDetail['rich_content'] = { meanings: [] };
  if (detailResp.ok) {
    const detailList = (await detailResp.json()) as VocabWordDetail[];
    if (detailList.length) {
      richContent = detailList[0].rich_content;
      // --- 脱敏处理：去掉 _source_meta ---
      if (richContent._source_meta) {
        delete richContent._source_meta;
      }
    }
  }

  // 3. 获取 word_examples
  const exResp = await supabaseFetch(env, '/word_examples', {
    select: '*',
    word_id: `eq.${id}`,
    order: 'sort_order.asc'
  });

  let examples: VocabExample[] = [];
  if (exResp.ok) {
    examples = (await exResp.json()) as VocabExample[];
  }

  const fullDetail: VocabFullDetail = {
    ...word,
    rich_content: richContent,
    examples: examples
  };

  return jsonResponse({ data: fullDetail }, corsHeaders(request));
}
