import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/preferences_provider.dart';
import '../models/vocab_book.dart';
import 'vocab_remote_query_provider.dart';

final selectedBookProvider = FutureProvider<VocabBook?>((ref) async {
  final selectedBookId = ref.watch(selectedBookIdProvider);
  if (selectedBookId == null) return null;

  final response = await ref.read(vocabRemoteQueryProvider).fetchBooks();
  for (final book in response.books) {
    if (book.id == selectedBookId) {
      return book;
    }
  }

  return null;
});
