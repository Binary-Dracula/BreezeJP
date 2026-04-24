import '../../../data/models/vocab_book.dart';

class BookSelectionState {
  final List<VocabBook> books;
  final bool isLoading;
  final bool isSyncing;
  final String? error;

  const BookSelectionState({
    this.books = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.error,
  });

  BookSelectionState copyWith({
    List<VocabBook>? books,
    bool? isLoading,
    bool? isSyncing,
    Object? error = _sentinel,
  }) {
    return BookSelectionState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}
