import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database_provider.dart';
import '../../data/queries/active_user_query_provider.dart';
import 'debug_reset_learning_command.dart';

final debugResetLearningCommandProvider =
    Provider<DebugResetLearningCommand>((ref) {
  final db = ref.read(databaseProvider);
  final activeUserQuery = ref.read(activeUserQueryProvider);
  return DebugResetLearningCommand(db, activeUserQuery);
});
