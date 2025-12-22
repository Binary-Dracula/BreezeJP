import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/read/study_log_item.dart';
import '../models/study_log.dart';

final studyLogQueryProvider = Provider<StudyLogQuery>((ref) {
  final db = ref.read(databaseProvider);
  return StudyLogQuery(db);
});

/// 学习日志查询层（只读）
class StudyLogQuery {
  StudyLogQuery(this._db);

  final Database _db;

  /// 获取用户的学习历史
  Future<List<StudyLogItem>> getUserLogs(
    int userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final results = await _db.query(
        'study_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return results.map(StudyLogItem.fromMap).toList();
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

  /// 获取特定类型的日志
  Future<List<StudyLogItem>> getLogsByType(
    int userId,
    LogType logType, {
    int? limit,
  }) async {
    try {
      final results = await _db.query(
        'study_logs',
        where: 'user_id = ? AND log_type = ?',
        whereArgs: [userId, logType.value],
        orderBy: 'created_at DESC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId AND log_type = ${logType.value}',
        resultCount: results.length,
      );

      return results.map(StudyLogItem.fromMap).toList();
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

  /// 获取指定日期范围的日志
  Future<List<StudyLogItem>> getLogsByDateRange(
    int userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
      final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

      final results = await _db.query(
        'study_logs',
        where: 'user_id = ? AND created_at >= ? AND created_at <= ?',
        whereArgs: [userId, startTimestamp, endTimestamp],
        orderBy: 'created_at DESC',
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId AND date range',
        resultCount: results.length,
      );

      return results.map(StudyLogItem.fromMap).toList();
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
