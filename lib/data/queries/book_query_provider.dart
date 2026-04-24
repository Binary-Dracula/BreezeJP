import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/preferences_provider.dart';
import '../repositories/book_repository_provider.dart';
import '../models/vocab_book.dart';
import 'book_query.dart';

final bookQueryProvider = Provider<BookQuery>((ref) {
  return BookQuery(ref.read(bookRepositoryProvider));
});

final selectedBookProvider = FutureProvider<VocabBook?>((ref) async {
  final selectedBookId = ref.watch(selectedBookIdProvider);
  if (selectedBookId == null) return null;
  return ref.read(bookQueryProvider).getBookById(selectedBookId);
});
