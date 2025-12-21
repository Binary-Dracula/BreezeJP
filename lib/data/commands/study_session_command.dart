import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_log.dart';
import 'daily_stat_command.dart';
import 'study_log_command.dart';
import 'study_word_command.dart';

/// Study session command (flow orchestration).
class StudySessionCommand {
  StudySessionCommand(this.ref);

  final Ref ref;

  StudyWordCommand get _studyWordCommand =>
      ref.read(studyWordCommandProvider);
  StudyLogCommand get _studyLogCommand =>
      ref.read(studyLogCommandProvider);
  DailyStatCommand get _dailyStatCommand =>
      ref.read(dailyStatCommandProvider);

  /// Submit a first-learn session for a word.
  Future<void> submitFirstLearn({
    required int userId,
    required int wordId,
    required int durationMs,
  }) async {
    await _studyWordCommand.markAsLearned(userId: userId, wordId: wordId);

    await _studyLogCommand.logFirstLearn(
      userId: userId,
      wordId: wordId,
      durationMs: durationMs,
    );

    await _dailyStatCommand.incrementLearnedWords(
      userId,
      DateTime.now(),
      count: 1,
    );

    await _dailyStatCommand.incrementStudyTime(
      userId,
      DateTime.now(),
      durationMs,
    );
  }

  /// Submit a review result.
  Future<void> submitReview({
    required int userId,
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    required double intervalAfter,
    required double easeFactorAfter,
    required DateTime nextReviewAtAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    int algorithm = 1,
  }) async {
    if (rating == ReviewRating.again) {
      await _studyWordCommand.submitIncorrectReview(
        userId,
        wordId,
        newInterval: intervalAfter,
        newEaseFactor: easeFactorAfter,
        newStability: fsrsStabilityAfter,
        newDifficulty: fsrsDifficultyAfter,
      );
    } else {
      await _studyWordCommand.submitCorrectReview(
        userId,
        wordId,
        newInterval: intervalAfter,
        newEaseFactor: easeFactorAfter,
        newStability: fsrsStabilityAfter,
        newDifficulty: fsrsDifficultyAfter,
      );
    }

    await _studyLogCommand.logReview(
      userId: userId,
      wordId: wordId,
      rating: rating,
      durationMs: durationMs,
      intervalAfter: intervalAfter,
      easeFactorAfter: easeFactorAfter,
      nextReviewAtAfter: nextReviewAtAfter,
      algorithm: algorithm,
      fsrsStabilityAfter: fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter,
    );

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

    await _dailyStatCommand.incrementStudyTime(
      userId,
      DateTime.now(),
      durationMs,
    );
  }
}
