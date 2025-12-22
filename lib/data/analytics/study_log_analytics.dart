import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/read/study_log_stats.dart';
import '../models/study_log.dart';

final studyLogAnalyticsProvider = Provider<StudyLogAnalytics>((ref) {
  final db = ref.read(databaseProvider);
  return StudyLogAnalytics(db);
});

/// 学习日志统计分析
class StudyLogAnalytics {
  StudyLogAnalytics(this._db);

  final Database _db;

  /// 获取学习日志统计汇总
  Future<StudyLogOverallStatistics> getStudyLogStats(int userId) async {
    return getOverallStatistics(userId);
  }

  /// 获取每日学习统计
  Future<List<StudyLogDailyStatistics>> getDailyStatistics(
    int userId, {
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final results = await _db.rawQuery(
        '''
        SELECT 
          DATE(created_at, 'unixepoch', 'localtime') as date,
          COUNT(*) as total_reviews,
          SUM(CASE WHEN log_type = 1 THEN 1 ELSE 0 END) as new_learned,
          SUM(CASE WHEN log_type = 2 THEN 1 ELSE 0 END) as reviews,
          SUM(duration_ms) as total_duration_ms,
          AVG(duration_ms) as avg_duration_ms
        FROM study_logs
        WHERE user_id = ? AND created_at >= ?
        GROUP BY date
        ORDER BY date DESC
      ''',
        [userId, startTimestamp],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId (daily stats)',
        resultCount: results.length,
      );

      return results
          .map((row) => StudyLogDailyStatistics.fromMap(row))
          .toList();
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

  /// 获取复习评分分布
  Future<List<StudyLogRatingCount>> getRatingDistribution(int userId) async {
    try {
      final results = await _db.rawQuery(
        '''
        SELECT rating, COUNT(*) as count
        FROM study_logs
        WHERE user_id = ? AND log_type = 2 AND rating IS NOT NULL
        GROUP BY rating
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId (rating distribution)',
        resultCount: results.length,
      );

      return results.map((row) {
        final rating = ReviewRating.fromValue(row['rating'] as int);
        final count = row['count'] as int;
        return StudyLogRatingCount(rating: rating, count: count);
      }).toList();
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

  /// 获取学习时长统计
  Future<StudyLogTimeStatistics> getTimeStatistics(
    int userId, {
    int days = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final result = await _db.rawQuery(
        '''
        SELECT 
          SUM(duration_ms) as total_ms,
          COUNT(*) as total_sessions,
          AVG(duration_ms) as avg_ms,
          MAX(duration_ms) as max_ms,
          MIN(duration_ms) as min_ms
        FROM study_logs
        WHERE user_id = ? AND created_at >= ?
      ''',
        [userId, startTimestamp],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId (time stats)',
        resultCount: 1,
      );

      return StudyLogTimeStatistics.fromMap(result.first);
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

  /// 获取学习热力图数据（用于日历视图）
  Future<List<StudyLogHeatmapItem>> getHeatmapData(
    int userId, {
    int days = 365,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final results = await _db.rawQuery(
        '''
        SELECT 
          DATE(created_at, 'unixepoch', 'localtime') as date,
          COUNT(*) as count
        FROM study_logs
        WHERE user_id = ? AND created_at >= ?
        GROUP BY date
      ''',
        [userId, startTimestamp],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId (heatmap)',
        resultCount: results.length,
      );

      return results.map((row) {
        final date = row['date'] as String;
        final count = row['count'] as int;
        return StudyLogHeatmapItem(date: date, count: count);
      }).toList();
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

  /// 获取总体学习统计
  Future<StudyLogOverallStatistics> getOverallStatistics(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_logs,
          COUNT(DISTINCT word_id) as unique_words,
          SUM(CASE WHEN log_type = 1 THEN 1 ELSE 0 END) as first_learns,
          SUM(CASE WHEN log_type = 2 THEN 1 ELSE 0 END) as reviews,
          SUM(duration_ms) as total_duration_ms,
          AVG(duration_ms) as avg_duration_ms,
          MIN(created_at) as first_log_at,
          MAX(created_at) as last_log_at
        FROM study_logs
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_logs',
        where: 'user_id = $userId (overall stats)',
        resultCount: 1,
      );

      return StudyLogOverallStatistics.fromMap(result.first);
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
