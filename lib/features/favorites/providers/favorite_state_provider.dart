import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/queries/favorite_query_provider.dart';
import 'favorite_refresh_provider.dart';

final wordFavoriteStateProvider = FutureProvider.family<bool, String>((
  ref,
  wordId,
) async {
  ref.watch(favoriteRefreshProvider);
  return ref.read(favoriteQueryProvider).isWordFavorited(wordId);
});

final wordExampleFavoriteStateProvider = FutureProvider.family<bool, String>((
  ref,
  exampleId,
) async {
  ref.watch(favoriteRefreshProvider);
  return ref.read(favoriteQueryProvider).isWordExampleFavorited(exampleId);
});
