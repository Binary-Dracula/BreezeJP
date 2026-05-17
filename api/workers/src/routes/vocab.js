import { corsHeaders } from '../middleware/cors';
import { supabaseFetch, jsonResponse, errorResponse, supabaseRpc } from '../utils/supabase';
const MAX_SESSION_LIMIT = 50;
/**
 * GET /api/v1/books/:bookId/next-words?after_sort=<N>&limit=<M>
 * 按 book_sort_order 顺序取下一批新词（含完整详情）
 * after_sort: 上一个已学词的 book_sort_order，0 表示从头开始
 * limit: 最多返回数量，默认 10，最大 50
 */
export async function handleNextWords(request, env, bookId) {
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
    const books = (await bookResp.json());
    const book = books[0];
    if (!book) {
        return errorResponse(404, 'BOOK_NOT_FOUND', 'Book not found');
    }
    if (!book.is_available) {
        return errorResponse(409, 'BOOK_UNAVAILABLE', 'Book is no longer available');
    }
    // 直接使用已持久化的 book_sort_order，避免每次请求重建整本书顺序。
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
export async function handleCreateLearnSession(request, env, auth) {
    let body;
    try {
        body = await request.json();
    }
    catch {
        return errorResponse(400, 'BAD_REQUEST', 'Invalid learn session payload');
    }
    const bookId = body.book_id?.trim();
    if (!bookId) {
        return errorResponse(400, 'BAD_REQUEST', 'book_id is required');
    }
    const limit = clampInt(body.limit == null ? null : String(body.limit), 10, 1, MAX_SESSION_LIMIT);
    const activeSession = await getActiveLearnSession(env, auth.sub, bookId);
    if (activeSession) {
        const totalWords = await fetchBookTotalWords(env, bookId);
        return jsonResponse({
            data: toLearnSessionEnvelope(activeSession),
            meta: {
                total_words: totalWords,
                resumed: true,
                server_time: new Date().toISOString(),
            },
        }, corsHeaders(request));
    }
    const bookResp = await supabaseFetch(env, '/books', {
        select: 'id,is_available,word_count',
        id: `eq.${bookId}`,
        limit: '1',
    });
    if (!bookResp.ok) {
        return errorResponse(500, 'DB_ERROR', 'Failed to validate book state');
    }
    const books = (await bookResp.json());
    const book = books[0];
    if (!book) {
        return errorResponse(404, 'BOOK_NOT_FOUND', 'Book not found');
    }
    if (!book.is_available) {
        return errorResponse(409, 'BOOK_UNAVAILABLE', 'Book is no longer available');
    }
    const [progressResp, sequenceRows, learnedIds] = await Promise.all([
        supabaseFetch(env, '/user_book_progress', {
            select: 'current_sort_cursor',
            user_id: `eq.${auth.sub}`,
            book_id: `eq.${bookId}`,
            limit: '1',
        }),
        fetchBookSequenceRows(env, bookId),
        fetchUserLearnedWordIds(env, auth.sub, bookId),
    ]);
    if (!progressResp.ok) {
        return errorResponse(500, 'DB_ERROR', 'Failed to read cloud book progress');
    }
    const progressRows = (await progressResp.json());
    const currentCursor = progressRows[0]?.current_sort_cursor ?? 0;
    const nextRows = sequenceRows
        .filter(row => row.book_sort_order > currentCursor && !learnedIds.has(row.word_id))
        .slice(0, limit);
    if (nextRows.length === 0) {
        return jsonResponse({
            data: emptyLearnSessionEnvelope(bookId, currentCursor),
            meta: {
                total_words: resolveBookWordCount(book.word_count, sequenceRows.length),
                resumed: false,
                server_time: new Date().toISOString(),
            },
        }, corsHeaders(request));
    }
    const wordIds = nextRows.map(row => row.word_id);
    const fullDetails = await fetchFullDetailsBatch(env, wordIds);
    const wordsPayload = nextRows.map(row => ({
        book_sort_order: row.book_sort_order,
        ...(fullDetails.get(row.word_id) ?? { id: row.word_id }),
    }));
    const createdSession = await createLearnSession(env, auth.sub, bookId, wordIds, wordsPayload, currentCursor, nextRows[nextRows.length - 1].book_sort_order, body.device_id?.trim() || null);
    return jsonResponse({
        data: toLearnSessionEnvelope(createdSession),
        meta: {
            total_words: resolveBookWordCount(book.word_count, sequenceRows.length),
            resumed: false,
            server_time: new Date().toISOString(),
        },
    }, corsHeaders(request));
}
export async function handleCompleteLearnSession(request, env, auth, sessionId) {
    let body;
    try {
        body = await request.json();
    }
    catch {
        return errorResponse(400, 'BAD_REQUEST', 'Invalid learn session payload');
    }
    const existing = await getLearnSessionById(env, auth.sub, sessionId);
    if (!existing) {
        return errorResponse(404, 'SESSION_NOT_FOUND', 'Learn session not found');
    }
    const submittedStates = Array.isArray(body.word_states) ? body.word_states : [];
    const submittedWordIds = new Set();
    const overrides = new Map();
    for (const entry of submittedStates) {
        const wordId = entry.word_id?.trim() ?? '';
        if (!wordId) {
            return errorResponse(400, 'BAD_REQUEST', 'word_states[].word_id is required');
        }
        if (!existing.word_ids.includes(wordId)) {
            return errorResponse(400, 'BAD_REQUEST', 'word_states contain word outside current session');
        }
        if (submittedWordIds.has(wordId)) {
            continue;
        }
        const userState = normalizeLearnUserState(entry.user_state);
        submittedWordIds.add(wordId);
        overrides.set(wordId, userState);
    }
    const finalWordStates = existing.word_ids.map(wordId => ({
        word_id: wordId,
        book_id: existing.book_id,
        user_state: overrides.get(wordId) ?? 1,
    }));
    const totalWords = await fetchBookTotalWords(env, existing.book_id);
    const rpcResponse = await supabaseRpc(env, 'complete_word_learning_session', {
        p_user_id: auth.sub,
        p_session_id: sessionId,
        p_word_states: finalWordStates,
        p_total_words: totalWords,
        p_first_review_interval_minutes: clampFirstReviewInterval(body.first_review_interval_minutes),
    });
    if (!rpcResponse.ok) {
        return errorResponse(500, 'DB_ERROR', 'Failed to complete learn session');
    }
    const payload = await rpcResponse.json();
    if (payload.applied !== true) {
        if (payload.reason === 'STALE_SESSION') {
            return errorResponse(409, 'STALE_SESSION', 'Learn session is stale');
        }
        return errorResponse(500, 'DB_ERROR', 'Failed to complete learn session');
    }
    return jsonResponse({
        data: {
            session_id: sessionId,
            status: 'completed',
            applied_count: finalWordStates.length,
        },
        meta: {
            total_words: totalWords,
            server_time: new Date().toISOString(),
        },
    }, corsHeaders(request));
}
/**
 * 获取用户在某本书中已有学习记录（任意 state）的 word_id 集合。
 * 用于学习会话创建时过滤，防止已学词再次出现在新批次里。
 */
async function fetchUserLearnedWordIds(env, userId, bookId) {
    const resp = await supabaseFetch(env, '/user_word_states', {
        select: 'word_id',
        user_id: `eq.${userId}`,
        book_id: `eq.${bookId}`,
        limit: '5000',
    });
    if (!resp.ok)
        return new Set();
    const rows = (await resp.json());
    return new Set(rows.map(r => r.word_id));
}
async function fetchBookTotalWords(env, bookId) {
    const bookResp = await supabaseFetch(env, '/books', {
        select: 'word_count',
        id: `eq.${bookId}`,
        limit: '1',
    });
    if (bookResp.ok) {
        const rows = (await bookResp.json());
        const count = rows[0]?.word_count;
        if (typeof count === 'number' && count >= 0) {
            return count;
        }
    }
    const countResp = await supabaseFetch(env, '/lesson_word_map', {
        select: 'id',
        book_id: `eq.${bookId}`,
        limit: '1',
    });
    if (!countResp.ok) {
        throw new Error('Failed to fetch book total words');
    }
    return parseContentRangeTotal(countResp.headers.get('content-range')) ?? 0;
}
/**
 * 批量获取词条完整详情（words + word_details + word_examples）
 */
export async function fetchFullDetailsBatch(env, wordIds) {
    const idFilter = `in.(${wordIds.join(',')})`;
    // 并行请求三张表
    const [wordsResp, detailsResp, examplesResp] = await Promise.all([
        supabaseFetch(env, '/words', { select: '*', id: idFilter }),
        supabaseFetch(env, '/word_details', { select: '*', word_id: idFilter }),
        supabaseFetch(env, '/word_examples', { select: '*', word_id: idFilter, order: 'sort_order.asc' }),
    ]);
    const wordsData = wordsResp.ok ? (await wordsResp.json()) : [];
    const detailsData = detailsResp.ok ? (await detailsResp.json()) : [];
    const examplesData = examplesResp.ok ? (await examplesResp.json()) : [];
    // 索引化
    const detailMap = new Map(detailsData.map(d => [d.word_id, d]));
    const exampleMap = new Map();
    for (const ex of examplesData) {
        const arr = exampleMap.get(ex.word_id) ?? [];
        arr.push(ex);
        exampleMap.set(ex.word_id, arr);
    }
    // 组装完整详情
    const result = new Map();
    for (const word of wordsData) {
        const detail = detailMap.get(word.id);
        let richContent = { meanings: [] };
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
export async function handleWordDetail(request, env, wordId, auth) {
    const details = await fetchFullDetailsBatch(env, [wordId]);
    const detail = details.get(wordId);
    if (!detail) {
        return errorResponse(404, 'WORD_NOT_FOUND', 'Word not found');
    }
    const favoriteState = auth == null
        ? { isFavorited: false, favoritedExampleIds: new Set() }
        : await fetchFavoriteState(env, auth.sub, wordId, detail.examples.map((example) => example.id));
    const data = {
        ...detail,
        is_favorited: favoriteState.isFavorited,
        examples: detail.examples.map((example) => ({
            ...example,
            is_favorited: favoriteState.favoritedExampleIds.has(example.id),
        })),
    };
    return jsonResponse({
        data,
        meta: { server_time: new Date().toISOString() },
    }, corsHeaders(request));
}
async function fetchFavoriteState(env, userId, wordId, exampleIds) {
    const [wordFavoriteResp, exampleFavoriteResp] = await Promise.all([
        supabaseFetch(env, '/user_word_favorites', {
            select: 'word_id',
            user_id: `eq.${userId}`,
            word_id: `eq.${wordId}`,
            limit: '1',
        }),
        exampleIds.length === 0
            ? Promise.resolve(null)
            : supabaseFetch(env, '/user_word_example_favorites', {
                select: 'example_id',
                user_id: `eq.${userId}`,
                example_id: `in.(${exampleIds.join(',')})`,
                limit: String(exampleIds.length),
            }),
    ]);
    if (!wordFavoriteResp.ok) {
        return { isFavorited: false, favoritedExampleIds: new Set() };
    }
    const wordFavoriteRows = (await wordFavoriteResp.json());
    const isFavorited = wordFavoriteRows.length > 0;
    if (exampleFavoriteResp == null || !exampleFavoriteResp.ok) {
        return { isFavorited, favoritedExampleIds: new Set() };
    }
    const exampleRows = (await exampleFavoriteResp.json());
    return {
        isFavorited,
        favoritedExampleIds: new Set(exampleRows.map((row) => row.example_id)),
    };
}
/**
 * GET /api/v1/books
 * 获取所有书籍列表
 */
export async function handleBookList(request, env) {
    const resp = await supabaseFetch(env, '/books', {
        select: '*',
        is_available: 'eq.true',
        order: 'sort_order.asc'
    });
    if (!resp.ok) {
        return errorResponse(500, 'INTERNAL_ERROR', 'Failed to fetch books');
    }
    const books = (await resp.json());
    const booksWithCount = await Promise.all(books.map(async (book) => {
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
    }));
    return jsonResponse({ data: booksWithCount }, corsHeaders(request));
}
async function fetchBookSequenceRows(env, bookId) {
    const mapResp = await supabaseFetch(env, '/lesson_word_map', {
        select: 'word_id,book_sort_order',
        book_id: `eq.${bookId}`,
        order: 'book_sort_order.asc',
        limit: '5000',
    });
    if (!mapResp.ok) {
        throw new Error('Failed to fetch sequence rows');
    }
    const mapRows = (await mapResp.json());
    return mapRows.map((row) => ({
        word_id: row.word_id,
        book_sort_order: row.book_sort_order,
    }));
}
async function getActiveLearnSession(env, userId, bookId) {
    const response = await supabaseFetch(env, '/user_learning_sessions', {
        select: '*',
        user_id: `eq.${userId}`,
        book_id: `eq.${bookId}`,
        status: 'eq.active',
        order: 'updated_at.desc',
        limit: '1',
    });
    if (!response.ok) {
        throw new Error('Failed to fetch active learn session');
    }
    const rows = (await response.json());
    return rows[0] ?? null;
}
async function getLearnSessionById(env, userId, sessionId) {
    const response = await supabaseFetch(env, '/user_learning_sessions', {
        select: '*',
        id: `eq.${sessionId}`,
        user_id: `eq.${userId}`,
        limit: '1',
    });
    if (!response.ok) {
        throw new Error('Failed to fetch learn session');
    }
    const rows = (await response.json());
    return rows[0] ?? null;
}
async function createLearnSession(env, userId, bookId, wordIds, wordsPayload, batchStartSort, batchEndSort, deviceId) {
    const response = await supabaseFetch(env, '/user_learning_sessions', undefined, {
        method: 'POST',
        headers: { Prefer: 'return=representation' },
        body: {
            user_id: userId,
            device_id: deviceId,
            book_id: bookId,
            status: 'active',
            word_ids: wordIds,
            words_payload: wordsPayload,
            batch_start_sort: batchStartSort,
            batch_end_sort: batchEndSort,
            completed_at: null,
        },
    });
    if (!response.ok) {
        throw new Error('Failed to create learn session');
    }
    const rows = (await response.json());
    if (!rows[0]) {
        throw new Error('Empty response while creating learn session');
    }
    return rows[0];
}
function toLearnSessionEnvelope(session) {
    return {
        session_id: session.id,
        book_id: session.book_id,
        batch_start_sort: session.batch_start_sort,
        batch_end_sort: session.batch_end_sort,
        words: Array.isArray(session.words_payload) ? session.words_payload : [],
    };
}
function emptyLearnSessionEnvelope(bookId, currentCursor) {
    return {
        session_id: null,
        book_id: bookId,
        batch_start_sort: currentCursor,
        batch_end_sort: currentCursor,
        words: [],
    };
}
function normalizeLearnUserState(value) {
    switch (value) {
        case 1:
        case 2:
        case 3:
            return value;
        case undefined:
            return 1;
        default:
            throw new Error('Invalid user_state');
    }
}
function clampFirstReviewInterval(value) {
    if (typeof value !== 'number' || Number.isNaN(value)) {
        return 10;
    }
    return Math.min(Math.max(Math.trunc(value), 1), 1440);
}
function clampInt(raw, fallback, min, max) {
    if (!raw) {
        return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    if (Number.isNaN(parsed)) {
        return fallback;
    }
    return Math.min(Math.max(parsed, min), max);
}
function parseContentRangeTotal(contentRange) {
    if (!contentRange) {
        return null;
    }
    const match = contentRange.match(/\/(\d+)$/);
    if (!match) {
        return null;
    }
    return parseInt(match[1], 10);
}
function resolveBookWordCount(wordCount, fallback) {
    if (typeof wordCount === 'number' && wordCount >= 0) {
        return wordCount;
    }
    return fallback;
}
