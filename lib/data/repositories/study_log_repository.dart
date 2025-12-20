import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_log.dart';

/// 学习日志数据仓库
/// 负责所有与学习日志相关的数据库操作
class StudyLogRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 创建学习日志
  Future<int> createLog(StudyLog log) async {
    try {
      final data = log.toMapForInsert();
      final db = await _db;
      final id = await db.insert('study_logs', data);

      logger.dbInsert(
        table: 'study_logs',
        id: id,
        keyFields: {'wordId': log.wordId, 'logType': log.logType.description},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 批量创建学习日志
  Future<void> createLogs(List<StudyLog> logs) async {
    try {
      final db = await _db;
      final batch = db.batch();

      for (final log in logs) {
        batch.insert('study_logs', log.toMapForInsert());
      }

      await batch.commit(noResult: true);
      logger.dbInsert(
        table: 'study_logs',
        id: 0,
        keyFields: {'batchCount': logs.length},
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'BATCH INSERT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取日志详情
  Future<StudyLog?> getLog(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_logs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return StudyLog.fromMap(results.first);
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

  /// 删除日志
  Future<void> deleteLog(int id) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'study_logs',
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.dbDelete(table: 'study_logs', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 查询方法 ====================

  /// 获取用户的学习历史
  Future<List<StudyLog>> getUserLogs(
    int userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _db;
      final results = await db.query(
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
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

  /// 获取某个单词的学习历史
  Future<List<StudyLog>> getWordLogs(int userId, int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_logs',
        where: 'user_id = ? AND word_id = ?',
        whereArgs: [userId, wordId],
        orderBy: 'created_at ASC',
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId AND word_id = $wordId',
        resultCount: results.length,
      );

      return results.map((map) => StudyLog.fromMap(map)).toList();
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
  Future<List<StudyLog>> getLogsByType(
    int userId,
    LogType logType, {
    int? limit,
  }) async {
    try {
      final db = await _db;
      final results = await db.query(
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
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
  Future<List<StudyLog>> getLogsByDateRange(
    int userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _db;
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
      final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

      final results = await db.query(
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
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

  // ==================== 清理方法 ====================

  /// 删除指定日期之前的日志（数据清理）
  Future<int> deleteLogsBeforeDate(DateTime date) async {
    try {
      final db = await _db;
      final timestamp = date.millisecondsSinceEpoch ~/ 1000;

      final count = await db.delete(
        'study_logs',
        where: 'created_at < ?',
        whereArgs: [timestamp],
      );

      logger.dbDelete(table: 'study_logs', deletedRows: count);
      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除用户的所有日志
  Future<int> deleteUserLogs(int userId) async {
    try {
      final db = await _db;
      final count = await db.delete(
        'study_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(table: 'study_logs', deletedRows: count);
      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
