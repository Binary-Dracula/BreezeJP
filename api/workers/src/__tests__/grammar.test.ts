import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  supabaseFetch: vi.fn(),
  jsonResponse: vi.fn(
    (body: unknown) => new Response(JSON.stringify(body), { status: 200 }),
  ),
  errorResponse: vi.fn(
    (status: number, code: string, message: string) =>
      new Response(JSON.stringify({ error: { code, message } }), { status }),
  ),
}));

vi.mock('../utils/supabase', () => ({
  supabaseFetch: mocks.supabaseFetch,
  jsonResponse: mocks.jsonResponse,
  errorResponse: mocks.errorResponse,
}));

vi.mock('../middleware/cors', () => ({
  corsHeaders: () => ({ 'Content-Type': 'application/json' }),
}));

import { handleGrammarList } from '../routes/grammar';

describe('grammar routes', () => {
  beforeEach(() => {
    mocks.supabaseFetch.mockReset();
    mocks.jsonResponse.mockClear();
    mocks.errorResponse.mockClear();
  });

  it('handleGrammarList normalizes uppercase jlpt filters to lowercase', async () => {
    mocks.supabaseFetch
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }));

    const response = await handleGrammarList(
      new Request('https://example.com/api/v1/grammars?limit=5&jlpt_level=N5'),
      {} as never,
      { sub: 'user-1' } as never,
    );

    expect(response.status).toBe(200);
    expect(mocks.supabaseFetch).toHaveBeenNthCalledWith(
      1,
      {} as never,
      '/grammars',
      expect.objectContaining({
        jlpt_level: 'eq.n5',
        limit: '2000',
      }),
    );
  });

  it('handleGrammarList keeps grammar content available when state queries fail', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
    const grammar = {
      id: 1,
      title: '〜ている',
      jlpt_level: 'n5',
      usage_frequency: 10,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    };

    mocks.supabaseFetch
      .mockResolvedValueOnce(new Response(JSON.stringify([grammar]), { status: 200 }))
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ message: 'relation "user_grammar_states" does not exist' }), {
          status: 500,
        }),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify([grammar]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ message: 'relation "user_grammar_states" does not exist' }), {
          status: 500,
        }),
      );

    const response = await handleGrammarList(
      new Request('https://example.com/api/v1/grammars?limit=5&jlpt_level=n5'),
      {} as never,
      { sub: 'user-1' } as never,
    );

    const payload = await response.json() as {
      data: Array<{ learning_status: number; learning_state: unknown }>;
    };

    expect(response.status).toBe(200);
    expect(payload.data).toHaveLength(1);
    expect(payload.data[0]).toMatchObject({
      learning_status: 0,
      learning_state: null,
    });
    expect(mocks.errorResponse).not.toHaveBeenCalled();

    warnSpy.mockRestore();
  });

  it('handleGrammarList retries without usage_frequency ordering when schema is older', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    mocks.supabaseFetch
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ message: 'column grammars.usage_frequency does not exist' }), {
          status: 400,
        }),
      )
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }));

    const response = await handleGrammarList(
      new Request('https://example.com/api/v1/grammars?limit=5'),
      {} as never,
      { sub: 'user-1' } as never,
    );

    expect(response.status).toBe(200);
    expect(mocks.supabaseFetch).toHaveBeenNthCalledWith(
      1,
      {} as never,
      '/grammars',
      expect.objectContaining({ order: 'usage_frequency.desc,id.asc' }),
    );
    expect(mocks.supabaseFetch).toHaveBeenNthCalledWith(
      3,
      {} as never,
      '/grammars',
      expect.objectContaining({ order: 'id.asc' }),
    );

    warnSpy.mockRestore();
  });
});