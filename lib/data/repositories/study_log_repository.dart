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
      logger.database('INSERT', table: 'study_logs', data: data);

      final db = await _db;
      final id = await db.insert('study_logs', data);

      logger.info(
        '创建学习日志: type=${log.logType.description}, word_id=${log.wordId}, id=$id',
      );
      return id;
    } catch (e, stackTrace) {
      logger.error('创建学习日志失败', e, stackTrace);
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
      logger.info('批量创建学习日志: ${logs.length} 条');
    } catch (e, stackTrace) {
      logger.error('批量创建学习日志失败', e, stackTrace);
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

      if (results.isEmpty) return null;
      return StudyLog.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取日志详情失败', e, stackTrace);
      rethrow;
    }
  }

  /// 删除日志
  Future<void> deleteLog(int id) async {
    try {
      final db = await _db;
      await db.delete('study_logs', where: 'id = ?', whereArgs: [id]);
      logger.info('删除学习日志: id=$id');
    } catch (e, stackTrace) {
      logger.error('删除学习日志失败', e, stackTrace);
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
      logger.database('SELECT', table: 'study_logs', data: {'user_id': userId});

      final db = await _db;
      final results = await db.query(
        'study_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((map) => StudyLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取用户学习历史失败', e, stackTrace);
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取单词学习历史失败', e, stackTrace);
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取特定类型日志失败', e, stackTrace);
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

      return results.map((map) => StudyLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取日期范围日志失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 统计方法 ====================

  /// 获取每日学习统计
  Future<List<Map<String, dynamic>>> getDailyStatistics(
    int userId, {
    int days = 30,
  }) async {
    try {
      logger.database('SELECT DAILY STATS', table: 'study_logs');

      final db = await _db;
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final results = await db.rawQuery(
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

      return results;
    } catch (e, stackTrace) {
      logger.error('获取每日统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取复习评分分布
  Future<Map<ReviewRating, int>> getRatingDistribution(int userId) async {
    try {
      final db = await _db;
      final results = await db.rawQuery(
        '''
        SELECT rating, COUNT(*) as count
        FROM study_logs
        WHERE user_id = ? AND log_type = 2 AND rating IS NOT NULL
        GROUP BY rating
      ''',
        [userId],
      );

      final distribution = <ReviewRating, int>{};
      for (final row in results) {
        final rating = ReviewRating.fromValue(row['rating'] as int);
        final count = row['count'] as int;
        distribution[rating] = count;
      }

      return distribution;
    } catch (e, stackTrace) {
      logger.error('获取评分分布失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取学习时长统计
  Future<Map<String, dynamic>> getTimeStatistics(
    int userId, {
    int days = 7,
  }) async {
    try {
      final db = await _db;
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final result = await db.rawQuery(
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

      return result.first;
    } catch (e, stackTrace) {
      logger.error('获取时长统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取学习热力图数据（用于日历视图）
  Future<Map<String, int>> getHeatmapData(int userId, {int days = 365}) async {
    try {
      final db = await _db;
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;

      final results = await db.rawQuery(
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

      final heatmap = <String, int>{};
      for (final row in results) {
        final date = row['date'] as String;
        final count = row['count'] as int;
        heatmap[date] = count;
      }

      return heatmap;
    } catch (e, stackTrace) {
      logger.error('获取热力图数据失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取总体学习统计
  Future<Map<String, dynamic>> getOverallStatistics(int userId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
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

      return result.first;
    } catch (e, stackTrace) {
      logger.error('获取总体统计失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 便捷方法 ====================

  /// 记录初次学习
  Future<int> logFirstLearn({
    required int userId,
    required int wordId,
    required int durationMs,
    double? intervalAfter,
    double? easeFactorAfter,
    DateTime? nextReviewAtAfter,
    int algorithm = 1, // 1: SM-2, 2: FSRS
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
  }) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.firstLearn,
      durationMs: durationMs,
      intervalAfter: intervalAfter,
      easeFactorAfter: easeFactorAfter,
      nextReviewAtAfter: nextReviewAtAfter,
      algorithm: algorithm,
      fsrsStabilityAfter: fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter,
      createdAt: DateTime.now(),
    );

    return await createLog(log);
  }

  /// 记录复习
  Future<int> logReview({
    required int userId,
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    required double intervalAfter,
    required double easeFactorAfter,
    required DateTime nextReviewAtAfter,
    int algorithm = 1, // 1: SM-2, 2: FSRS
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
  }) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.review,
      rating: rating,
      durationMs: durationMs,
      intervalAfter: intervalAfter,
      easeFactorAfter: easeFactorAfter,
      nextReviewAtAfter: nextReviewAtAfter,
      algorithm: algorithm,
      fsrsStabilityAfter: fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter,
      createdAt: DateTime.now(),
    );

    return await createLog(log);
  }

  /// 记录标记已掌握
  Future<int> logMarkMastered({
    required int userId,
    required int wordId,
  }) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.markMastered,
      createdAt: DateTime.now(),
    );

    return await createLog(log);
  }

  /// 记录标记忽略
  Future<int> logMarkIgnored({required int userId, required int wordId}) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.markIgnored,
      createdAt: DateTime.now(),
    );

    return await createLog(log);
  }

  /// 记录重置进度
  Future<int> logReset({required int userId, required int wordId}) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.reset,
      createdAt: DateTime.now(),
    );

    return await createLog(log);
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

      logger.info('删除旧日志: $count 条');
      return count;
    } catch (e, stackTrace) {
      logger.error('删除旧日志失败', e, stackTrace);
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

      logger.info('删除用户日志: $count 条');
      return count;
    } catch (e, stackTrace) {
      logger.error('删除用户日志失败', e, stackTrace);
      rethrow;
    }
  }
}
