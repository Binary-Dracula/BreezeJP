import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_stat.dart';
import '../repositories/daily_stat_repository.dart';
import '../repositories/daily_stat_repository_provider.dart';

final dailyStatCommandProvider = Provider<DailyStatCommand>((ref) {
  return DailyStatCommand(ref);
});

/// DailyStat 行为命令层（更新 / 写入）
class DailyStatCommand {
  DailyStatCommand(this.ref);

  final Ref ref;

  DailyStatRepository get _repo => ref.read(dailyStatRepositoryProvider);

  /// 更新每日统计（用于学习会话结束时）
  Future<void> updateDailyStats({
    required int userId,
    required int learnedCount,
    required int durationMs,
  }) async {
    final stat = await _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );
    final updated = stat.copyWith(
      totalTimeMs: stat.totalTimeMs + durationMs,
      newLearnedCount: stat.newLearnedCount + learnedCount,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 增加学习时长
  Future<void> incrementStudyTime(
    int userId,
    DateTime date,
    int milliseconds,
  ) async {
    final stat = await _ensureDailyStat(userId: userId, date: date);
    final updated = stat.copyWith(
      totalTimeMs: stat.totalTimeMs + milliseconds,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 增加新学单词数
  Future<void> incrementLearnedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    final stat = await _ensureDailyStat(userId: userId, date: date);
    final updated = stat.copyWith(
      newLearnedCount: stat.newLearnedCount + count,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 增加复习单词数
  Future<void> incrementReviewedWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    final stat = await _ensureDailyStat(userId: userId, date: date);
    final updated = stat.copyWith(
      reviewCount: stat.reviewCount + count,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 增加掌握单词数
  Future<void> incrementMasteredWords(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    final stat = await _ensureDailyStat(userId: userId, date: date);
    final updated = stat.copyWith(
      uniqueKanaReviewedCount: stat.uniqueKanaReviewedCount + count,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 增加错误次数
  Future<void> incrementFailedCount(
    int userId,
    DateTime date, {
    int count = 1,
  }) async {
    final stat = await _ensureDailyStat(userId: userId, date: date);
    final updated = stat.copyWith(
      reviewCount: stat.reviewCount + count,
    );
    await _repo.updateDailyStat(updated);
  }

  /// 删除指定日期之前的统计
  Future<int> deleteStatsBeforeDate(DateTime date) async {
    return _repo.deleteBeforeDate(date);
  }

  /// 删除用户的所有统计
  Future<int> deleteUserStats(int userId) async {
    return _repo.deleteByUser(userId);
  }

  /// 删除每日统计
  Future<void> deleteDailyStat(int id) async {
    await _repo.deleteDailyStat(id);
  }

  /// 确保指定日期存在统计记录
  Future<DailyStat> ensureTodayStat(int userId) async {
    return _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );
  }

  Future<DailyStat> _ensureDailyStat({
    required int userId,
    required DateTime date,
  }) async {
    final stat = await _repo.getByDate(userId, date);
    if (stat != null) return stat;

    final newStat = DailyStat.createForDate(userId, date);
    final id = await _repo.insertDailyStat(newStat);
    return newStat.copyWith(id: id);
  }
}
