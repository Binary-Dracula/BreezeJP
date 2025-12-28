import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/kana_log.dart';
import '../models/study_log.dart';

final todayLearningAnalyticsProvider =
    Provider<TodayLearningAnalytics>((ref) {
  final db = ref.read(databaseProvider);
  return TodayLearningAnalytics(db);
});

/// 今日学习统计分析
class TodayLearningAnalytics {
  TodayLearningAnalytics(this._db);

  final Database _db;

  /// 获取今日学习数（单词 + 假名）
  Future<int> getTodayLearnedCount({
    required int userId,
    required int startTs,
    required int endTs,
  }) async {
    try {
      final wordResult = await _db.rawQuery(
        '''
        SELECT COUNT(DISTINCT word_id) as count
        FROM study_logs
        WHERE user_id = ?
          AND log_type = ?
          AND created_at >= ?
          AND created_at < ?
      ''',
        [userId, LogType.firstLearn.value, startTs, endTs],
      );
      final wordCount = (wordResult.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'study_logs',
        where:
            'user_id = $userId AND log_type = ${LogType.firstLearn.value} (today distinct)',
        resultCount: 1,
      );

      final kanaResult = await _db.rawQuery(
        '''
        SELECT COUNT(DISTINCT kana_id) as count
        FROM kana_logs
        WHERE user_id = ?
          AND log_type = ?
          AND created_at >= ?
          AND created_at < ?
      ''',
        [userId, KanaLogType.firstLearn.index + 1, startTs, endTs],
      );
      final kanaCount = (kanaResult.first['count'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_logs',
        where:
            'user_id = $userId AND log_type = ${KanaLogType.firstLearn.index + 1} (today distinct)',
        resultCount: 1,
      );

      return wordCount + kanaCount;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_logs + kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
