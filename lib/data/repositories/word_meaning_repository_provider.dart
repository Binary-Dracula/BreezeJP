import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'word_meaning_repository.dart';

/// WordMeaningRepository Provider
final wordMeaningRepositoryProvider = Provider<WordMeaningRepository>((ref) {
  return WordMeaningRepository(() => AppDatabase.instance.database);
});
