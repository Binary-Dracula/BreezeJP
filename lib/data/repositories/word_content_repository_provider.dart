import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'word_content_repository.dart';

final wordContentRepositoryProvider = Provider<WordContentRepository>((ref) {
  return WordContentRepository(() => AppDatabase.instance.database);
});
