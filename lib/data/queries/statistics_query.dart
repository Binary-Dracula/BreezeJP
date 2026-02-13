import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/read/user_word_statistics.dart';

final statisticsQueryProvider = Provider<StatisticsQuery>((ref) {
  final db = ref.read(databaseProvider);
  return StatisticsQuery(db);
});

/// 详细统计页专用查询（只读）
class StatisticsQuery {
  StatisticsQuery(this._db);

  final Database _db;

  /// 获取用户全量总学习时长（毫秒）
  Future<int> getTotalStudyTimeMs(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT COALESCE(SUM(total_time_ms), 0) as total_time_ms
        FROM daily_stats
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (total study time)',
        resultCount: 1,
      );

      return (result.first['total_time_ms'] as num?)?.toInt() ?? 0;
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

  /// 获取单词状态分布统计
  Future<UserWordStatistics> getWordStatusDistribution(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT
          COUNT(*) as total_words,
          SUM(CASE WHEN user_state = 0 THEN 1 ELSE 0 END) as new_words,
          SUM(CASE WHEN user_state = 1 THEN 1 ELSE 0 END) as learning_words,
          SUM(CASE WHEN user_state = 2 THEN 1 ELSE 0 END) as mastered_words,
          SUM(CASE WHEN user_state = 3 THEN 1 ELSE 0 END) as ignored_words,
          COALESCE(SUM(total_reviews), 0) as total_reviews,
          COALESCE(AVG(ease_factor), 2.5) as avg_ease_factor,
          COALESCE(SUM(fail_count), 0) as total_fails
        FROM study_words
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id = $userId (word status distribution)',
        resultCount: 1,
      );

      return UserWordStatistics.fromMap(result.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取全量时段汇总（最近 1 年）
  Future<Map<String, dynamic>> getAllTimeSummary(int userId) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT
          SUM(total_time_ms) as total_time,
          SUM(new_learned_count) as total_learned,
          SUM(review_count) as total_reviewed,
          AVG(total_time_ms) as avg_time_per_day,
          COUNT(*) as active_days
        FROM daily_stats
        WHERE user_id = ?
          AND date >= DATE('now', '-1 year')
          AND date <= DATE('now')
          AND (new_learned_count > 0 OR review_count > 0 OR total_time_ms > 0)
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (all time summary)',
        resultCount: 1,
      );

      return result.first;
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
}
