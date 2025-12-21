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

  Future<void> applySession({
    required int userId,
    required int learned,
    required int reviewed,
    required int failed,
    required int mastered,
    required int durationMs,
    required int kanaReviewCount,
  }) async {
    if (learned == 0 &&
        reviewed == 0 &&
        failed == 0 &&
        mastered == 0 &&
        durationMs == 0 &&
        kanaReviewCount == 0) {
      return;
    }

    final stat = await _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );

    final updated = stat.copyWith(
      totalTimeMs: stat.totalTimeMs + durationMs,
      newLearnedCount: stat.newLearnedCount + learned,
      reviewCount: stat.reviewCount + reviewed,
      uniqueKanaReviewedCount:
          stat.uniqueKanaReviewedCount + kanaReviewCount + mastered,
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
