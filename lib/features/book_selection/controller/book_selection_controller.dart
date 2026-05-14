import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/queries/vocab_remote_query_provider.dart';
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
      final response = await ref.read(vocabRemoteQueryProvider).fetchBooks();
      state = state.copyWith(
        books: response.books,
        isLoading: false,
        isSyncing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isSyncing: false, error: '$e');
    }
  }

  Future<void> refreshBooks() async {
    try {
      state = state.copyWith(isLoading: true, isSyncing: true, error: null);
      final books = await ref.read(vocabRemoteQueryProvider).fetchBooks();
      state = state.copyWith(
        books: books.books,
        isLoading: false,
        isSyncing: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isSyncing: false, error: '$e');
    }
  }
}
