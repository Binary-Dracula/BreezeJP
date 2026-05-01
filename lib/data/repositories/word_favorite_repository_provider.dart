import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'word_favorite_repository.dart';

final wordFavoriteRepositoryProvider = Provider<WordFavoriteRepository>((ref) {
  return WordFavoriteRepository(() => AppDatabase.instance.database);
});
