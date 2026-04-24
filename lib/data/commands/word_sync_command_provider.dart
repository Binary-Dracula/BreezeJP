import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'word_sync_command.dart';

final wordSyncCommandProvider = Provider<WordSyncCommand>((ref) {
  final db = ref.read(databaseProvider);
  return WordSyncCommand(db);
});
