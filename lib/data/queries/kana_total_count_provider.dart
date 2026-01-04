import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kana_query_provider.dart';

/// Cached total kana count for the whole app.
final kanaTotalCountProvider = FutureProvider<int>((ref) async {
  final query = ref.watch(kanaQueryProvider);
  return query.countTotalKana();
});
