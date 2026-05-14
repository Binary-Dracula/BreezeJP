import { corsHeaders } from '../middleware/cors';
import { errorResponse, jsonResponse, supabaseFetch } from '../utils/supabase';
export async function handleKanaStates(request, env, auth) {
    const response = await supabaseFetch(env, '/user_kana_states', {
        select: '*',
        user_id: `eq.${auth.sub}`,
        order: 'kana_id.asc',
        limit: '500',
    });
    if (!response.ok) {
        return errorResponse(500, 'DB_ERROR', 'Failed to fetch kana states');
    }
    const rows = await response.json();
    return jsonResponse({
        data: rows,
        meta: { server_time: new Date().toISOString() },
    }, corsHeaders(request));
}
export async function handleUpsertKanaStates(request, env, auth) {
    let body;
    try {
        body = await request.json();
    }
    catch {
        return errorResponse(400, 'BAD_REQUEST', 'Invalid JSON body');
    }
    const inputStates = Array.isArray(body.states)
        ? body.states ?? []
        : [body];
    const states = inputStates
        .map((state) => normalizeKanaState(state, auth.sub))
        .filter((state) => state != null);
    if (states.length === 0) {
        return errorResponse(400, 'BAD_REQUEST', 'No valid kana states provided');
    }
    const response = await supabaseFetch(env, '/user_kana_states', { on_conflict: 'user_id,kana_id' }, {
        method: 'POST',
        headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
        body: states,
    });
    if (!response.ok) {
        return errorResponse(500, 'DB_ERROR', 'Failed to upsert kana states');
    }
    const rows = await response.json();
    return jsonResponse({
        data: rows,
        meta: {
            count: states.length,
            server_time: new Date().toISOString(),
        },
    }, corsHeaders(request));
}
function normalizeKanaState(state, userId) {
    const kanaId = toInt(state.kana_id);
    const learningStatus = toInt(state.learning_status);
    if (kanaId == null || learningStatus == null) {
        return null;
    }
    return {
        user_id: userId,
        kana_id: kanaId,
        learning_status: learningStatus,
        next_review_at: toNullableInt(state.next_review_at),
        last_reviewed_at: toNullableInt(state.last_reviewed_at),
        streak: toInt(state.streak),
        total_reviews: toInt(state.total_reviews),
        fail_count: toInt(state.fail_count),
        interval: toNullableNumber(state.interval),
        ease_factor: toNullableNumber(state.ease_factor),
        stability: toNullableNumber(state.stability),
        difficulty: toNullableNumber(state.difficulty),
    };
}
function toInt(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
        return Math.trunc(value);
    }
    if (typeof value === 'string' && value.trim().length > 0) {
        const parsed = Number.parseInt(value, 10);
        return Number.isNaN(parsed) ? null : parsed;
    }
    return null;
}
function toNullableInt(value) {
    if (value == null) {
        return null;
    }
    return toInt(value);
}
function toNullableNumber(value) {
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
