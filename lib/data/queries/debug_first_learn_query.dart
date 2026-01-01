import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/study_log.dart';

final debugFirstLearnQueryProvider = Provider<DebugFirstLearnQuery>((ref) {
  final db = ref.read(databaseProvider);
  return DebugFirstLearnQuery(db);
});

class DebugFirstLearnItem {
  final int wordId;
  final int userId;
  final DateTime createdAt;

  const DebugFirstLearnItem({
    required this.wordId,
    required this.userId,
    required this.createdAt,
  });

  bool get isToday {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return createdAt.isAfter(startOfToday);
  }

  factory DebugFirstLearnItem.fromMap(Map<String, dynamic> map) {
    return DebugFirstLearnItem(
      wordId: map['word_id'] as int,
      userId: map['user_id'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }
}

/// firstLearn 日志查询（只读）
class DebugFirstLearnQuery {
  DebugFirstLearnQuery(this._db);

  final Database _db;

  Future<List<DebugFirstLearnItem>> getRecentFirstLearns(int userId) async {
    try {
      final results = await _db.query(
        'study_logs',
        columns: ['word_id', 'user_id', 'created_at'],
        where: 'user_id = ? AND log_type = ?',
        whereArgs: [userId, LogType.firstLearn.value],
        orderBy: 'created_at DESC',
        limit: 50,
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId AND log_type = ${LogType.firstLearn.value}',
        resultCount: results.length,
      );

      return results.map(DebugFirstLearnItem.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
