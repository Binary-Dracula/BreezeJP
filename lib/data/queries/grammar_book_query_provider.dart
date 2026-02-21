import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database_provider.dart';
import 'grammar_book_query.dart';

final grammarBookQueryProvider = Provider<GrammarBookQuery>((ref) {
  final db = ref.watch(databaseProvider);
  return GrammarBookQuery(db);
});
