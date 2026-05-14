import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env } from '../types';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';

type ToggleWordFavoriteRequest = {
  word_id?: string;
};

type ToggleExampleFavoriteRequest = {
  example_id?: string;
  word_id?: string;
};

export async function handleToggleWordFavorite(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: ToggleWordFavoriteRequest;
  try {
    body = await request.json<ToggleWordFavoriteRequest>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  const wordId = body.word_id?.trim();
  if (!wordId) {
    return errorResponse(400, 'BAD_REQUEST', 'Missing required field: word_id');
  }

  const existingResp = await supabaseFetch(env, '/user_word_favorites', {
    select: 'word_id',
    user_id: `eq.${auth.sub}`,
    word_id: `eq.${wordId}`,
    limit: '1',
  });
  if (!existingResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to query word favorite');
  }

  const existingRows = (await existingResp.json()) as Array<{ word_id: string }>;
  if (existingRows.length > 0) {
    const deleteResp = await supabaseFetch(
      env,
      '/user_word_favorites',
      {
        user_id: `eq.${auth.sub}`,
        word_id: `eq.${wordId}`,
      },
      { method: 'DELETE' },
    );
    if (!deleteResp.ok) {
      return errorResponse(500, 'DB_ERROR', 'Failed to remove word favorite');
    }

    return jsonResponse(
      {
        data: { favorited: false },
        meta: { server_time: new Date().toISOString() },
      },
      corsHeaders(request),
    );
  }

  const bookId = await resolveBookIdForWord(env, auth.sub, wordId);
  if (!bookId) {
    return errorResponse(404, 'WORD_NOT_FOUND', 'Unable to resolve book for word');
  }

  const insertResp = await supabaseFetch(
    env,
    '/user_word_favorites',
    undefined,
    {
      method: 'POST',
      body: {
        user_id: auth.sub,
        word_id: wordId,
        book_id: bookId,
      },
    },
  );
  if (!insertResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to add word favorite');
  }

  return jsonResponse(
    {
      data: { favorited: true },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

export async function handleToggleExampleFavorite(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  let body: ToggleExampleFavoriteRequest;
  try {
    body = await request.json<ToggleExampleFavoriteRequest>();
  } catch {
    return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
  }

  const exampleId = body.example_id?.trim();
  const wordId = body.word_id?.trim();
  if (!exampleId || !wordId) {
    return errorResponse(
      400,
      'BAD_REQUEST',
      'Missing required fields: example_id and word_id',
    );
  }

  const existingResp = await supabaseFetch(env, '/user_word_example_favorites', {
    select: 'example_id',
    user_id: `eq.${auth.sub}`,
    example_id: `eq.${exampleId}`,
    limit: '1',
  });
  if (!existingResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to query example favorite');
  }

  const existingRows = (await existingResp.json()) as Array<{ example_id: string }>;
  if (existingRows.length > 0) {
    const deleteResp = await supabaseFetch(
      env,
      '/user_word_example_favorites',
      {
        user_id: `eq.${auth.sub}`,
        example_id: `eq.${exampleId}`,
      },
      { method: 'DELETE' },
    );
    if (!deleteResp.ok) {
      return errorResponse(500, 'DB_ERROR', 'Failed to remove example favorite');
    }

    return jsonResponse(
      {
        data: { favorited: false },
        meta: { server_time: new Date().toISOString() },
      },
      corsHeaders(request),
    );
  }

  const insertResp = await supabaseFetch(
    env,
    '/user_word_example_favorites',
    undefined,
    {
      method: 'POST',
      body: {
        user_id: auth.sub,
        example_id: exampleId,
        word_id: wordId,
      },
    },
  );
  if (!insertResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to add example favorite');
  }

  return jsonResponse(
    {
      data: { favorited: true },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

async function resolveBookIdForWord(
  env: Env,
  userId: string,
  wordId: string,
): Promise<string | null> {
  const stateResp = await supabaseFetch(env, '/user_word_states', {
    select: 'book_id',
    user_id: `eq.${userId}`,
    word_id: `eq.${wordId}`,
    order: 'updated_at.desc',
    limit: '1',
  });

  if (stateResp.ok) {
    const stateRows = (await stateResp.json()) as Array<{ book_id: string }>;
    if (stateRows.length > 0 && stateRows[0].book_id.trim().length > 0) {
      return stateRows[0].book_id;
    }
  }

  const contentResp = await supabaseFetch(env, '/lesson_word_map', {
    select: 'book_id',
    word_id: `eq.${wordId}`,
    order: 'book_sort_order.asc',
    limit: '1',
  });
  if (!contentResp.ok) {
    return null;
  }

  const contentRows = (await contentResp.json()) as Array<{ book_id: string }>;
  return contentRows[0]?.book_id ?? null;
}
