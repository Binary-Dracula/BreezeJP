import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/read/user_word_statistics.dart';

final studyWordAnalyticsProvider = Provider<StudyWordAnalytics>((ref) {
  final db = ref.read(databaseProvider);
  return StudyWordAnalytics(db);
});

/// StudyWord 统计分析
class StudyWordAnalytics {
  StudyWordAnalytics(this._db);

  final Database _db;

  /// 获取用户的学习统计
  Future<UserWordStatistics> getUserStatistics(int userId) async {
    try {
      final db = _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_words,
          SUM(CASE WHEN user_state = 0 THEN 1 ELSE 0 END) as new_words,
          SUM(CASE WHEN user_state = 1 THEN 1 ELSE 0 END) as learning_words,
          SUM(CASE WHEN user_state = 2 THEN 1 ELSE 0 END) as mastered_words,
          SUM(CASE WHEN user_state = 3 THEN 1 ELSE 0 END) as ignored_words,
          SUM(total_reviews) as total_reviews,
          AVG(ease_factor) as avg_ease_factor,
          SUM(fail_count) as total_fails
        FROM study_words
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id = $userId (statistics)',
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
}
