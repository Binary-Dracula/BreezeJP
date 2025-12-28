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

  /// 应用单次学习增量（初学/复习）
  Future<void> applyLearningDelta({
    required int userId,
    required int learnedDelta,
    required int reviewedDelta,
    required int durationMs,
  }) async {
    if (learnedDelta == 0 && reviewedDelta == 0 && durationMs == 0) {
      return;
    }

    final stat = await _ensureDailyStat(
      userId: userId,
      date: DateTime.now(),
    );

    final updated = stat.copyWith(
      totalTimeMs: stat.totalTimeMs + durationMs,
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
