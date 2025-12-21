import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'kana_query.dart';

final kanaQueryProvider = Provider<KanaQuery>((ref) {
  final db = ref.read(databaseProvider);
  return KanaQuery(db);
});
