import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_stat.dart';
import '../queries/active_user_query_provider.dart';
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

  /// 仅用于页面驻留时间写入（工程封板）
  ///
  /// ⚠️ 这是写入 total_time_ms 的【唯一入口】
  ///
  /// 禁止：
  /// - 行为侧调用
  /// - session 侧调用
  /// - 任何非页面生命周期的时间写入
  /// 仅应用学习时长（页面驻留时间）
  Future<void> applyTimeOnlyDelta({
    required int durationMs,
    required DateTime date,
  }) async {
    if (durationMs <= 0) return;

    final userId = await ref.read(activeUserQueryProvider).getActiveUserId();
    if (userId == null) return;

    final stat = await _ensureDailyStat(
      userId: userId,
      date: date,
    );

    final updated = stat.copyWith(
      totalTimeMs: stat.totalTimeMs + durationMs,
    );
    await _repo.update(updated);
  }

  /// 应用单次学习增量（初学/复习）
  Future<void> applyLearningDelta({
    required int userId,
    required int learnedDelta,
    required int reviewedDelta,
  }) async {
    if (learnedDelta == 0 && reviewedDelta == 0) {
      return;
    }

    final stat = await _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );

    final updated = stat.copyWith(
      newLearnedCount: stat.newLearnedCount + learnedDelta,
      reviewCount: stat.reviewCount + reviewedDelta,
    );
    await _repo.update(updated);
  }

  Future<void> applySession({
    required int userId,
    required int learned,
    required int reviewed,
    required int failed,
    required int mastered,
    required int kanaReviewCount,
  }) async {
    if (learned == 0 &&
        reviewed == 0 &&
        failed == 0 &&
        mastered == 0 &&
        kanaReviewCount == 0) {
      return;
    }

    final stat = await _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );

    final updated = stat.copyWith(
      newLearnedCount: stat.newLearnedCount + learned,
      reviewCount: stat.reviewCount + reviewed,
      uniqueKanaReviewedCount:
          stat.uniqueKanaReviewedCount + kanaReviewCount + mastered,
    );
    await _repo.update(updated);
  }

  Future<DailyStat> _ensureDailyStat({
    required int userId,
    required DateTime date,
  }) async {
    final stat = await _repo.getByUserAndDate(userId, _formatDate(date));
    if (stat != null) return stat;

    final newStat = DailyStat.createForDate(userId, date);
    final id = await _repo.insert(newStat);
    return newStat.copyWith(id: id);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
