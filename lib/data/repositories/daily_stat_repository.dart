import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/daily_stat.dart';

/// 每日统计数据仓库
/// 负责所有与每日学习统计相关的数据库操作
class DailyStatRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 获取指定日期的统计
  Future<DailyStat?> getByDate(int userId, DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final db = await _db;
      final results = await db.query(
        'daily_stats',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId AND date = $dateStr',
        resultCount: results.length,
      );

      return results.isEmpty ? null : DailyStat.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新每日统计
  Future<void> updateDailyStat(DailyStat stat) async {
    try {
      final db = await _db;
      final affectedRows = await db.update(
        'daily_stats',
        stat.toMap(),
        where: 'id = ?',
        whereArgs: [stat.id],
      );

      logger.dbUpdate(
        table: 'daily_stats',
        affectedRows: affectedRows,
        updatedFields: ['total_time_ms', 'new_learned_count', 'review_count'],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 创建每日统计
  Future<int> insertDailyStat(DailyStat stat) async {
    try {
      final data = stat.toMapForInsert();
      final db = await _db;
      final id = await db.insert('daily_stats', data);

      logger.dbInsert(
        table: 'daily_stats',
        id: id,
        keyFields: {'date': stat.dateString, 'userId': stat.userId},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除指定日期之前的统计
  Future<int> deleteBeforeDate(DateTime date) async {
    try {
      final db = await _db;
      final dateStr = _formatDate(date);

      final count = await db.delete(
        'daily_stats',
        where: 'date < ?',
        whereArgs: [dateStr],
      );

      logger.dbDelete(table: 'daily_stats', deletedRows: count);
      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除用户的所有统计
  Future<int> deleteByUser(int userId) async {
    try {
      final db = await _db;
      final count = await db.delete(
        'daily_stats',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(table: 'daily_stats', deletedRows: count);
      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除每日统计
  Future<void> deleteDailyStat(int id) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'daily_stats',
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.dbDelete(table: 'daily_stats', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
