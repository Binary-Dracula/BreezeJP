import { AuthPayload } from '../middleware/auth';
import { corsHeaders } from '../middleware/cors';
import { Env } from '../types';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';

type UserProfileRow = {
  display_name: string | null;
};

export async function handleHomeSummary(
  request: Request,
  env: Env,
  auth: AuthPayload,
): Promise<Response> {
  const nowSeconds = Math.floor(Date.now() / 1000);

  const [profileResp, wordReviewResp, kanaReviewResp, wordMasteredResp, kanaMasteredResp] = await Promise.all([
    supabaseFetch(env, '/user_profiles', {
      select: 'display_name',
      user_id: `eq.${auth.sub}`,
      limit: '1',
    }),
    supabaseFetch(env, '/user_word_states', {
      select: 'word_id',
      user_id: `eq.${auth.sub}`,
      user_state: 'eq.1',
      or: `(next_review_at.is.null,next_review_at.lte.${nowSeconds})`,
      limit: '1',
    }),
    supabaseFetch(env, '/user_kana_states', {
      select: 'kana_id',
      user_id: `eq.${auth.sub}`,
      learning_status: 'eq.1',
      or: `(next_review_at.is.null,next_review_at.lte.${nowSeconds})`,
      limit: '1',
    }),
    supabaseFetch(env, '/user_word_states', {
      select: 'word_id',
      user_id: `eq.${auth.sub}`,
      user_state: 'eq.2',
      limit: '1',
    }),
    supabaseFetch(env, '/user_kana_states', {
      select: 'kana_id',
      user_id: `eq.${auth.sub}`,
      learning_status: 'eq.2',
      limit: '1',
    }),
  ]);

  if (!profileResp.ok || !wordReviewResp.ok || !kanaReviewResp.ok || !wordMasteredResp.ok || !kanaMasteredResp.ok) {
    return errorResponse(500, 'DB_ERROR', 'Failed to fetch home summary');
  }

  const profileRows = (await profileResp.json()) as UserProfileRow[];
  const userName = profileRows[0]?.display_name?.trim() || 'BreezeJP User';
  const reviewCount = parseContentRangeTotal(wordReviewResp.headers.get('content-range')) ?? 0;
  const kanaReviewCount = parseContentRangeTotal(kanaReviewResp.headers.get('content-range')) ?? 0;
  const masteredWordCount = parseContentRangeTotal(
    wordMasteredResp.headers.get('content-range'),
  ) ?? 0;
  const kanaMasteredCount = parseContentRangeTotal(
    kanaMasteredResp.headers.get('content-range'),
  ) ?? 0;

  return jsonResponse(
    {
      data: {
        user_name: userName,
        review_count: reviewCount,
        kana_review_count: kanaReviewCount,
        mastered_word_count: masteredWordCount,
        kana_mastered_count: kanaMasteredCount,
      },
      meta: { server_time: new Date().toISOString() },
    },
    corsHeaders(request),
  );
}

function parseContentRangeTotal(contentRange: string | null): number | null {
  if (!contentRange) {
    return null;
  }
  const parts = contentRange.split('/');
  if (parts.length !== 2) {
    return null;
  }
  const total = Number.parseInt(parts[1], 10);
  return Number.isNaN(total) ? null : total;
}