import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/commands/book_sync_command_provider.dart';
import '../../../data/queries/book_query_provider.dart';
import '../state/book_selection_state.dart';

final bookSelectionControllerProvider =
    NotifierProvider<BookSelectionController, BookSelectionState>(
      BookSelectionController.new,
    );

class BookSelectionController extends Notifier<BookSelectionState> {
  @override
  BookSelectionState build() {
    Future.microtask(loadBooks);
    return const BookSelectionState();
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true, isSyncing: false, error: null);

    try {
      final localBooks = await ref.read(bookQueryProvider).getAvailableBooks();
      if (localBooks.isNotEmpty) {
        state = state.copyWith(
          books: localBooks,
          isLoading: false,
          isSyncing: false,
          error: null,
        );
        _silentRefreshBooks();
        return;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isSyncing: false, error: '$e');
      return;
    }

    await refreshBooks();
  }

  Future<void> refreshBooks() async {
    try {
      state = state.copyWith(isLoading: true, isSyncing: true, error: null);
      await ref.read(bookSyncCommandProvider).syncBooks();
      final books = await ref.read(bookQueryProvider).getAvailableBooks();
      state = state.copyWith(
        books: books,
        isLoading: false,
        isSyncing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isSyncing: false, error: '$e');
    }
  }

  void _silentRefreshBooks() {
    Future<void>(() async {
      try {
        await ref.read(bookSyncCommandProvider).syncBooks();
        final books = await ref.read(bookQueryProvider).getAvailableBooks();
        state = state.copyWith(books: books, isSyncing: false);
      } catch (_) {
        // Keep current UI when background refresh fails.
      }
    });
  }
}
