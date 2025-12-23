import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/daily_stat.dart';

/// 每日统计数据仓库
/// 仅负责 daily_stats 表的基础 CRUD
class DailyStatRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 获取指定 ID 的统计
  Future<DailyStat?> getById(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'daily_stats',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'id = $id',
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

  /// 获取指定用户与日期的统计
  Future<DailyStat?> getByUserAndDate(int userId, String date) async {
    try {
      final db = await _db;
      final results = await db.query(
        'daily_stats',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
        limit: 1,
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId AND date = $date',
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

  /// 创建每日统计
  Future<int> insert(DailyStat stat) async {
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

  /// 更新每日统计
  Future<void> update(DailyStat stat) async {
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

  /// 删除每日统计
  Future<void> deleteById(int id) async {
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
}
