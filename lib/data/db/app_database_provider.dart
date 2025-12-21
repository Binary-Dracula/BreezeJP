import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

final databaseProvider = Provider<Database>((ref) {
  return AppDatabase.instance.databaseSync;
});
