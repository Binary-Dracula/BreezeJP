import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/daily_stat.dart';
import '../models/read/daily_stat_stats.dart';

final dailyStatQueryProvider = Provider<DailyStatQuery>((ref) {
  final db = ref.read(databaseProvider);
  return DailyStatQuery(db);
});

/// DailyStat 查询层（统计 / 报表）
class DailyStatQuery {
  DailyStatQuery(this._db);

  final Database _db;

  /// 获取用户的所有每日统计
  Future<List<DailyStat>> getUserDailyStats(
    int userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final db = _db;
      final results = await db.query(
        'daily_stats',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return results.map((map) => DailyStat.fromMap(map)).toList();
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

  /// 获取日期范围内的统计
  Future<List<DailyStat>> getDailyStatsByDateRange(
    int userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = _db;
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      final results = await db.query(
        'daily_stats',
        where: 'user_id = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startStr, endStr],
        orderBy: 'date ASC',
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId AND date range',
        resultCount: results.length,
      );

      return results.map((map) => DailyStat.fromMap(map)).toList();
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

  /// 获取最近 N 天的统计
  Future<List<DailyStat>> getRecentDailyStats(
    int userId, {
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));

      return await getDailyStatsByDateRange(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
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

  /// 计算学习连续天数（streak）
  Future<int> calculateStreak(int userId) async {
    try {
      final db = _db;

      final result = await db.rawQuery(
        '''
        WITH active_days AS (
          SELECT date
          FROM daily_stats
          WHERE user_id = ?
            AND (new_learned_count > 0 OR review_count > 0 OR total_time_ms > 0)
        ),
        ranked AS (
          SELECT
            date,
            julianday(date) - ROW_NUMBER() OVER (ORDER BY date DESC) AS grp
          FROM active_days
        ),
        anchor AS (
          SELECT grp
          FROM ranked
          WHERE date = (
            SELECT MAX(date)
            FROM active_days
            WHERE date = DATE('now','localtime')
               OR date = DATE('now','localtime','-1 day')
          )
        )
        SELECT
          CASE
            WHEN EXISTS (SELECT 1 FROM anchor)
            THEN (SELECT COUNT(*) FROM ranked WHERE grp = (SELECT grp FROM anchor))
            ELSE 0
          END AS count;

      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (streak)',
        resultCount: 1,
      );

      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e, stackTrace) {
      logger.error(
        'calculateStreak failed (streak query on daily_stats)',
        e,
        stackTrace,
      );
      return 0;
    }
  }

  /// 获取学习热力图数据
  Future<List<DailyStatHeatmapItem>> getHeatmapData(
    int userId, {
    int days = 365,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));

      final stats = await getDailyStatsByDateRange(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      return stats
          .map(
            (stat) => DailyStatHeatmapItem(
              date: stat.dateString,
              count: stat.totalWordsCount,
            ),
          )
          .toList();
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

  /// 获取本周统计汇总
  Future<DailyStatSummary> getWeeklySummary(int userId) async {
    try {
      final db = _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(total_time_ms) as total_time,
          SUM(new_learned_count) as total_learned,
          SUM(review_count) as total_reviewed,
          SUM(unique_kana_reviewed_count) as total_mastered,
          AVG(total_time_ms) as avg_time_per_day,
          COUNT(*) as active_days
        FROM daily_stats
        WHERE user_id = ?
          AND date >= DATE('now', 'weekday 0', '-7 days')
          AND date <= DATE('now')
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (weekly summary)',
        resultCount: 1,
      );

      return DailyStatSummary.fromMap(result.first);
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

  /// 获取本月统计汇总
  Future<DailyStatSummary> getMonthlySummary(int userId) async {
    try {
      final db = _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(total_time_ms) as total_time,
          SUM(new_learned_count) as total_learned,
          SUM(review_count) as total_reviewed,
          SUM(unique_kana_reviewed_count) as total_mastered,
          AVG(total_time_ms) as avg_time_per_day,
          COUNT(*) as active_days
        FROM daily_stats
        WHERE user_id = ?
          AND date >= DATE('now', 'start of month')
          AND date <= DATE('now')
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (monthly summary)',
        resultCount: 1,
      );

      return DailyStatSummary.fromMap(result.first);
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

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
