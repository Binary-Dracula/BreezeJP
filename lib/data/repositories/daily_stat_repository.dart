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
      logger.database(
        'SELECT',
        table: 'daily_stats',
        data: {'user_id': userId, 'date': dateStr},
      );

      final db = await _db;
      final results = await db.query(
        'daily_stats',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return DailyStat.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取每日统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 创建每日统计
  Future<int> createDailyStat(DailyStat stat) async {
    try {
      logger.database('INSERT', table: 'daily_stats', data: stat.toMap());

      final db = await _db;
      final id = await db.insert('daily_stats', stat.toMap());

      logger.info('创建每日统计: date=${stat.dateString}');
      return id;
    } catch (e, stackTrace) {
      logger.error('创建每日统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新每日统计
  Future<void> updateDailyStat(DailyStat stat) async {
    try {
      logger.database('UPDATE', table: 'daily_stats', data: stat.toMap());

      final db = await _db;
      await db.update(
        'daily_stats',
        stat.toMap(),
        where: 'id = ?',
        whereArgs: [stat.id],
      );

      logger.info('更新每日统计: id=${stat.id}');
    } catch (e, stackTrace) {
      logger.error('更新每日统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 删除每日统计
  Future<void> deleteDailyStat(int id) async {
    try {
      final db = await _db;
      await db.delete('daily_stats', where: 'id = ?', whereArgs: [id]);
      logger.info('删除每日统计: id=$id');
    } catch (e, stackTrace) {
      logger.error('删除每日统计失败', e, stackTrace);
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

      return results.map((map) => DailyStat.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取用户每日统计失败', e, stackTrace);
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

      return results.map((map) => DailyStat.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取日期范围统计失败', e, stackTrace);
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
      logger.error('获取最近统计失败', e, stackTrace);
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

  /// 增加学习时长
  Future<void> incrementStudyTime(
    int userId,
    DateTime date,
    int seconds,
  ) async {
    try {
      final stat = await getDailyStat(userId, date);

      if (stat == null) {
        // 创建新记录
        final newStat = DailyStat.createForDate(
          userId,
          date,
        ).copyWith(totalStudyTime: seconds, updatedAt: DateTime.now());
        await createDailyStat(newStat);
      } else {
        // 更新现有记录
        final updated = stat.copyWith(
          totalStudyTime: stat.totalStudyTime + seconds,
          updatedAt: DateTime.now(),
        );
        await updateDailyStat(updated);
      }

      logger.info('增加学习时长: +${seconds}秒');
    } catch (e, stackTrace) {
      logger.error('增加学习时长失败', e, stackTrace);
      rethrow;
    }
  }

  /// 增加新学单词数
  Future<void> incrementLearnedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'learned_words_count', count);
  }

  /// 增加复习单词数
  Future<void> incrementReviewedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'reviewed_words_count', count);
  }

  /// 增加掌握单词数
  Future<void> incrementMasteredWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'mastered_words_count', count);
  }

  /// 增加错误次数
  Future<void> incrementFailedCount(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    await _incrementField(userId, date, 'failed_count', count);
  }

  /// 通用字段增加方法
  Future<void> _incrementField(
    int userId,
    DateTime date,
    String fieldName,
    int increment,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 使用 INSERT OR REPLACE 确保记录存在
      await db.rawInsert(
        '''
        INSERT INTO daily_stats (user_id, date, $fieldName, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
          $fieldName = $fieldName + ?,
          updated_at = ?
      ''',
        [userId, dateStr, increment, now, now, increment, now],
      );

      logger.info('增加 $fieldName: +$increment');
    } catch (e, stackTrace) {
      logger.error('增加字段失败: $fieldName', e, stackTrace);
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
          SUM(total_study_time) as total_time,
          SUM(learned_words_count) as total_learned,
          SUM(reviewed_words_count) as total_reviewed,
          SUM(mastered_words_count) as total_mastered,
          SUM(failed_count) as total_failed,
          AVG(total_study_time) as avg_time_per_day,
          COUNT(*) as active_days
        FROM daily_stats
        WHERE user_id = ?
          AND date >= DATE('now', 'weekday 0', '-7 days')
          AND date <= DATE('now')
      ''',
        [userId],
      );

      return result.first;
    } catch (e, stackTrace) {
      logger.error('获取本周统计失败', e, stackTrace);
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
          SUM(total_study_time) as total_time,
          SUM(learned_words_count) as total_learned,
          SUM(reviewed_words_count) as total_reviewed,
          SUM(mastered_words_count) as total_mastered,
          SUM(failed_count) as total_failed,
          AVG(total_study_time) as avg_time_per_day,
          COUNT(*) as active_days
        FROM daily_stats
        WHERE user_id = ?
          AND date >= DATE('now', 'start of month')
          AND date <= DATE('now')
      ''',
        [userId],
      );

      return result.first;
    } catch (e, stackTrace) {
      logger.error('获取本月统计失败', e, stackTrace);
      rethrow;
    }
  }

  /// 计算学习连续天数（streak）
  Future<int> calculateStreak(int userId) async {
    try {
      final db = await _db;

      // 获取最近的学习日期
      final recentDays = await db.rawQuery(
        '''
        SELECT date
        FROM daily_stats
        WHERE user_id = ?
          AND (learned_words_count > 0 OR reviewed_words_count > 0)
        ORDER BY date DESC
        LIMIT 365
      ''',
        [userId],
      );

      if (recentDays.isEmpty) return 0;

      // 检查是否包含今天或昨天
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final todayStr = _formatDate(today);
      final yesterdayStr = _formatDate(yesterday);

      final latestDate = recentDays.first['date'] as String;
      if (latestDate != todayStr && latestDate != yesterdayStr) {
        return 0; // 连续天数已中断
      }

      // 计算连续天数
      int streak = 0;
      DateTime currentDate = DateTime.parse(latestDate);

      for (final row in recentDays) {
        final dateStr = row['date'] as String;
        final date = DateTime.parse(dateStr);

        if (_isSameDay(date, currentDate) ||
            _isSameDay(date, currentDate.subtract(Duration(days: streak)))) {
          streak++;
          currentDate = date;
        } else {
          break;
        }
      }

      return streak;
    } catch (e, stackTrace) {
      logger.error('计算连续天数失败', e, stackTrace);
      rethrow;
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
      logger.error('获取热力图数据失败', e, stackTrace);
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

      logger.info('删除旧统计: $count 条');
      return count;
    } catch (e, stackTrace) {
      logger.error('删除旧统计失败', e, stackTrace);
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

      logger.info('删除用户统计: $count 条');
      return count;
    } catch (e, stackTrace) {
      logger.error('删除用户统计失败', e, stackTrace);
      rethrow;
    }
  }
}
