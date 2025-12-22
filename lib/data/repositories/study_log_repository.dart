import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_log.dart';

/// 学习日志数据仓库
/// 仅负责 study_logs 表的基础 CRUD
class StudyLogRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 创建学习日志
  Future<int> insertStudyLog(StudyLog log) async {
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

  /// 删除日志
  Future<void> deleteStudyLog(int id) async {
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

  /// 删除用户的所有日志
  Future<int> deleteLogsByUser(int userId) async {
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
