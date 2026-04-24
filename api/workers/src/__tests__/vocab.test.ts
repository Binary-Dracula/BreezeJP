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

import { handleBookList, handleBookSync, handleNextWords } from '../routes/vocab';

describe('vocab routes', () => {
  beforeEach(() => {
    mocks.supabaseFetch.mockReset();
    mocks.jsonResponse.mockClear();
    mocks.errorResponse.mockClear();
  });

  it('handleBookList requests only available books', async () => {
    mocks.supabaseFetch
      .mockResolvedValueOnce(
        new Response(JSON.stringify([{ id: 'book-1', title: 'N1', is_available: true, has_lessons: true, word_count: 1 }]), { status: 200 }),
      )
      .mockResolvedValueOnce(
        new Response(null, {
          status: 200,
          headers: { 'content-range': '0-0/10' },
        }),
      );

    await handleBookList(new Request('https://example.com/api/v1/books'), {} as never);

    expect(mocks.supabaseFetch).toHaveBeenCalledWith(
      {} as never,
      '/books',
      expect.objectContaining({ is_available: 'eq.true', order: 'sort_order.asc' }),
    );
  });

  it('handleBookSync queries books updated after since', async () => {
    mocks.supabaseFetch.mockResolvedValueOnce(
      new Response(JSON.stringify([]), { status: 200 }),
    );

    await handleBookSync(
      new Request('https://example.com/api/v1/books/sync?since=2026-04-22T10:00:00Z'),
      {} as never,
    );

    expect(mocks.supabaseFetch).toHaveBeenCalledWith(
      {} as never,
      '/books',
      expect.objectContaining({ updated_at: 'gt.2026-04-22T10:00:00Z', order: 'updated_at.asc' }),
    );
  });

  it('handleNextWords blocks unavailable books', async () => {
    mocks.supabaseFetch.mockResolvedValueOnce(
      new Response(JSON.stringify([{ id: 'book-1', is_available: false }]), { status: 200 }),
    );

    const response = await handleNextWords(
      new Request('https://example.com/api/v1/books/book-1/next-words'),
      {} as never,
      'book-1',
    );

    expect(response.status).toBe(409);
    expect(mocks.errorResponse).toHaveBeenCalledWith(
      409,
      'BOOK_UNAVAILABLE',
      'Book is no longer available',
    );
  });
});