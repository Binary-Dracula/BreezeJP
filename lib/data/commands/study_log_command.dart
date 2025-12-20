import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_log.dart';
import '../repositories/study_log_repository.dart';
import '../repositories/study_log_repository_provider.dart';
import 'daily_stat_command.dart';

final studyLogCommandProvider = Provider<StudyLogCommand>((ref) {
  return StudyLogCommand(ref);
});

/// 学习日志写入命令（含统计副作用）
class StudyLogCommand {
  StudyLogCommand(this.ref);

  final Ref ref;

  StudyLogRepository get _repo => ref.read(studyLogRepositoryProvider);
  DailyStatCommand get _dailyStatCommand =>
      ref.read(dailyStatCommandProvider);

  /// 记录首次学习
  Future<int> logFirstLearn({
    required int userId,
    required int wordId,
    required int durationMs,
    double? intervalAfter,
    double? easeFactorAfter,
    DateTime? nextReviewAtAfter,
    int algorithm = 1,
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

    final id = await _repo.createLog(log);

    await _dailyStatCommand.incrementLearnedWords(
      userId,
      DateTime.now(),
      count: 1,
    );

    return id;
  }

  /// 记录复习
  Future<int> logReview({
    required int userId,
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    double? intervalAfter,
    double? easeFactorAfter,
    DateTime? nextReviewAtAfter,
    int algorithm = 1,
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

    final id = await _repo.createLog(log);

    await _dailyStatCommand.incrementReviewedWords(
      userId,
      DateTime.now(),
      count: 1,
    );

    if (rating == ReviewRating.again) {
      await _dailyStatCommand.incrementFailedCount(
        userId,
        DateTime.now(),
        count: 1,
      );
    }

    return id;
  }

  /// 标记已掌握
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

    final id = await _repo.createLog(log);

    await _dailyStatCommand.incrementMasteredWords(
      userId,
      DateTime.now(),
      count: 1,
    );

    return id;
  }

  /// 标记忽略
  Future<int> logMarkIgnored({
    required int userId,
    required int wordId,
  }) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.markIgnored,
      createdAt: DateTime.now(),
    );

    return _repo.createLog(log);
  }

  /// 重置进度
  Future<int> logReset({
    required int userId,
    required int wordId,
  }) async {
    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      logType: LogType.reset,
      createdAt: DateTime.now(),
    );

    return _repo.createLog(log);
  }
}
