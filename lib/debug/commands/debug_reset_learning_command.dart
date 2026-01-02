import 'package:sqflite/sqflite.dart';

import '../../data/queries/active_user_query.dart';

/// Debug-only command to reset learning data for the active user.
class DebugResetLearningCommand {
  DebugResetLearningCommand(this._db, this._activeUserQuery);

  final Database _db;
  final ActiveUserQuery _activeUserQuery;

  Future<void> resetLearningData() async {
    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      throw StateError('No active user');
    }

    await _db.transaction((txn) async {
      await txn.delete(
        'study_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'study_words',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'kana_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'kana_learning_state',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
  }
}
