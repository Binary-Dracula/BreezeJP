import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_log.dart';
import 'daily_stat_command.dart';
import 'session/review_result.dart';
import 'session/study_session_context.dart';
import 'study_log_command.dart';
import 'study_word_command.dart';

/// Study session command (flow orchestration).
class StudySessionCommand {
  StudySessionCommand(this.ref);

  final Ref ref;
  StudySessionContext? _ctx;

  StudyWordCommand get _studyWordCommand =>
      ref.read(studyWordCommandProvider);
  StudyLogCommand get _studyLogCommand =>
      ref.read(studyLogCommandProvider);
  DailyStatCommand get _dailyStatCommand =>
      ref.read(dailyStatCommandProvider);

  void startSession(int userId) {
    _ctx = StudySessionContext(userId: userId);
  }

  /// Submit a first-learn session for a word.
  Future<void> submitFirstLearn({
    required int wordId,
    required int durationMs,
  }) async {
    final ctx = _requireContext();
    if (durationMs > 0) {
      ctx.addDuration(durationMs);
    }
    ctx.markLearned();

    await _studyWordCommand.markAsLearned(userId: ctx.userId, wordId: wordId);

    await _studyLogCommand.logFirstLearn(
      userId: ctx.userId,
      wordId: wordId,
      durationMs: durationMs,
    );
  }

  /// Submit a review result.
  Future<void> submitReview({
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    required ReviewResult reviewResult,
    int algorithm = 1,
  }) async {
    final ctx = _requireContext();
    if (durationMs > 0) {
      ctx.addDuration(durationMs);
    }

    final isCorrect = rating != ReviewRating.again;
    ctx.markReviewed();
    if (!isCorrect) {
      ctx.markFailed();
    }

    await _studyWordCommand.applyReviewResult(
      userId: ctx.userId,
      wordId: wordId,
      isCorrect: isCorrect,
      reviewResult: reviewResult,
    );

    await _studyLogCommand.logReview(
      userId: ctx.userId,
      wordId: wordId,
      rating: rating,
      durationMs: durationMs,
      intervalAfter: reviewResult.intervalAfter,
      easeFactorAfter: reviewResult.easeFactorAfter,
      nextReviewAtAfter: reviewResult.nextReviewAtAfter,
      algorithm: algorithm,
      fsrsStabilityAfter: reviewResult.fsrsStabilityAfter,
      fsrsDifficultyAfter: reviewResult.fsrsDifficultyAfter,
    );
  }

  Future<void> submitKanaReview({
    required int rating,
    required int durationMs,
  }) async {
    final ctx = _requireContext();
    if (durationMs > 0) {
      ctx.addDuration(durationMs);
    }

    ctx.markReviewed();
    if (rating <= 1) {
      ctx.markFailed();
    }
  }

  Future<void> flush() async {
    final ctx = _ctx;
    if (ctx == null) return;

    await _dailyStatCommand.applySession(
      userId: ctx.userId,
      learned: ctx.learned,
      reviewed: ctx.reviewed,
      failed: ctx.failed,
      mastered: ctx.mastered,
      durationMs: ctx.durationMs,
    );

    _ctx = null;
  }

  StudySessionContext _requireContext() {
    final ctx = _ctx;
    if (ctx == null) {
      throw StateError('Study session is not started.');
    }
    return ctx;
  }
}
