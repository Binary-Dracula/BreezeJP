import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_log.dart';
import '../repositories/study_log_repository.dart';
import '../repositories/study_log_repository_provider.dart';
final studyLogCommandProvider = Provider<StudyLogCommand>((ref) {
  return StudyLogCommand(ref);
});

/// 学习日志写入命令
class StudyLogCommand {
  StudyLogCommand(this.ref);

  final Ref ref;

  StudyLogRepository get _repo => ref.read(studyLogRepositoryProvider);

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
      questionType: 'recall',
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

    final id = await _repo.insert(log);

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
      questionType: 'recall',
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

    final id = await _repo.insert(log);

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
      questionType: 'recall',
      logType: LogType.markMastered,
      createdAt: DateTime.now(),
    );

    final id = await _repo.insert(log);

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
      questionType: 'recall',
      logType: LogType.markIgnored,
      createdAt: DateTime.now(),
    );

    return _repo.insert(log);
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
      questionType: 'recall',
      logType: LogType.reset,
      createdAt: DateTime.now(),
    );

    return _repo.insert(log);
  }
}
