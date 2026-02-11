import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'vocabulary_book_query.dart';

final vocabularyBookQueryProvider = Provider<VocabularyBookQuery>((ref) {
  final db = ref.read(databaseProvider);
  return VocabularyBookQuery(db);
});
