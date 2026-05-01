import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'word_example_favorite_repository.dart';

final wordExampleFavoriteRepositoryProvider =
    Provider<WordExampleFavoriteRepository>((ref) {
      return WordExampleFavoriteRepository(() => AppDatabase.instance.database);
    });
