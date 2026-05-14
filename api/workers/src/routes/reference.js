import { corsHeaders } from '../middleware/cors';
import { jsonResponse } from '../utils/supabase';
import { referenceData } from '../data/reference';
export async function handleReferenceContent(request) {
    return jsonResponse({
        data: referenceData,
        meta: {
            server_time: new Date().toISOString(),
        },
    }, corsHeaders(request));
}
