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
  Future<DailyStat?> getDailyStat(int userId, DateTime date) async {
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

      if (results.isEmpty) return null;
      return DailyStat.fromMap(results.first);
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
  Future<int> createDailyStat(DailyStat stat) async {
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

  // ==================== 查询方法 ====================

  /// 获取用户的所有每日统计
  Future<List<DailyStat>> getUserDailyStats(
    int userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _db;
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
      final db = await _db;
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

  // ==================== 更新方法 ====================

  /// 获取或创建今日统计
  Future<DailyStat> getOrCreateTodayStat(int userId) async {
    final today = DateTime.now();
    final stat = await getDailyStat(userId, today);

    if (stat != null) return stat;

    // 创建新的今日统计
    final newStat = DailyStat.createToday(userId);
    final id = await createDailyStat(newStat);

    return newStat.copyWith(id: id);
  }

  /// 更新每日统计（用于学习会话结束时）
  Future<void> updateDailyStats({
    required int userId,
    required int learnedCount,
    required int durationMs,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = _formatDate(today);
      final db = await _db;

      // 尝试获取今天的记录
      final existing = await db.query(
        'daily_stats',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
      );

      if (existing.isEmpty) {
        // 创建新记录
        final id = await db.insert('daily_stats', {
          'user_id': userId,
          'date': dateStr,
          'total_time_ms': durationMs,
          'new_learned_count': learnedCount,
          'review_count': 0,
        });

        logger.dbInsert(
          table: 'daily_stats',
          id: id,
          keyFields: {'date': dateStr, 'learned': learnedCount},
        );
      } else {
        // 累加更新
        final existingStat = DailyStat.fromMap(existing.first);
        final affectedRows = await db.update(
          'daily_stats',
          {
            'total_time_ms': existingStat.totalTimeMs + durationMs,
            'new_learned_count':
                existingStat.newLearnedCount + learnedCount,
          },
          where: 'user_id = ? AND date = ?',
          whereArgs: [userId, dateStr],
        );

        logger.dbUpdate(
          table: 'daily_stats',
          affectedRows: affectedRows,
          updatedFields: ['total_time_ms', 'new_learned_count'],
        );
      }
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 增加学习时长
  Future<void> incrementStudyTime(
    int userId,
    DateTime date,
    int milliseconds,
  ) async {
    try {
      final stat = await getDailyStat(userId, date);

      if (stat == null) {
        // 创建新记录
        final newStat = DailyStat.createForDate(
          userId,
          date,
        ).copyWith(totalTimeMs: milliseconds);
        await createDailyStat(newStat);
      } else {
        // 更新现有记录
        final updated = stat.copyWith(
          totalTimeMs: stat.totalTimeMs + milliseconds,
        );
        await updateDailyStat(updated);
      }
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

  /// 增加新学单词数
  Future<void> incrementLearnedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'new_learned_count', count);
  }

  /// 增加复习单词数
  Future<void> incrementReviewedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'review_count', count);
  }

  /// 增加掌握单词数
  Future<void> incrementMasteredWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'unique_kana_reviewed_count', count);
  }

  /// 增加错误次数
  Future<void> incrementFailedCount(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'review_count', count);
  }

  /// 通用字段增加方法
  Future<void> _incrementField(
    int userId,
    DateTime date,
    String fieldName,
    int increment,
  ) async {
    try {
      const allowedFields = {
        'new_learned_count',
        'review_count',
        'total_time_ms',
        'unique_kana_reviewed_count',
      };
      if (!allowedFields.contains(fieldName)) {
        logger.warning(
          'daily_stats increment ignored for unsupported field: $fieldName',
        );
        return;
      }
      final dateStr = _formatDate(date);
      final db = await _db;

      await db.rawInsert(
        '''
        INSERT INTO daily_stats (user_id, date, $fieldName)
        VALUES (?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
          $fieldName = $fieldName + ?
      ''',
        [userId, dateStr, increment, increment],
      );

      logger.dbUpdate(
        table: 'daily_stats',
        affectedRows: 1,
        updatedFields: [fieldName],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'daily_stats',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 统计方法 ====================

  /// 获取本周统计汇总
  Future<Map<String, dynamic>> getWeeklySummary(int userId) async {
    try {
      final db = await _db;
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

  /// 获取本月统计汇总
  Future<Map<String, dynamic>> getMonthlySummary(int userId) async {
    try {
      final db = await _db;
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

  /// 计算学习连续天数（streak）
  Future<int> calculateStreak(int userId) async {
    try {
      final db = await _db;

      final recentDays = await db.rawQuery(
        '''
        SELECT date
        FROM daily_stats
        WHERE user_id = ?
          AND (new_learned_count > 0 OR review_count > 0 OR total_time_ms > 0)
        ORDER BY date DESC
        LIMIT 365
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'daily_stats',
        where: 'user_id = $userId (streak)',
        resultCount: recentDays.length,
      );

      if (recentDays.isEmpty) return 0;

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final todayStr = _formatDate(today);
      final yesterdayStr = _formatDate(yesterday);

      final latestDateStr = recentDays.first['date'] as String;
      if (latestDateStr != todayStr && latestDateStr != yesterdayStr) {
        return 0;
      }

      int streak = 0;
      DateTime expectedDate = DateTime.parse(latestDateStr);

      for (final row in recentDays) {
        final dateStr = row['date'] as String;
        final date = DateTime.parse(dateStr);

        if (_isSameDay(date, expectedDate)) {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
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
  Future<Map<String, int>> getHeatmapData(int userId, {int days = 365}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));

      final stats = await getDailyStatsByDateRange(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      final heatmap = <String, int>{};
      for (final stat in stats) {
        heatmap[stat.dateString] = stat.totalWordsCount;
      }

      return heatmap;
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

  // ==================== 辅助方法 ====================

  /// 格式化日期为 YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 判断两个日期是否为同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ==================== 清理方法 ====================

  /// 删除指定日期之前的统计
  Future<int> deleteStatsBeforeDate(DateTime date) async {
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
  Future<int> deleteUserStats(int userId) async {
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
