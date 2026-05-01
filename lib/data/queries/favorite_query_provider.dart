import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'active_user_query_provider.dart';
import 'favorite_query.dart';

final favoriteQueryProvider = Provider<FavoriteQuery>((ref) {
  final db = ref.read(databaseProvider);
  final activeUserQuery = ref.read(activeUserQueryProvider);
  return FavoriteQuery(db, activeUserQuery);
});
