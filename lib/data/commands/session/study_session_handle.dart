import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_log.dart';
import '../daily_stat_command.dart';
import '../study_log_command.dart';
import '../study_word_command.dart';
import 'review_result.dart';
import 'study_session_context.dart';

class StudySessionHandle {
  final StudySessionContext ctx;
  final Ref ref;
  bool _flushed = false;

  StudySessionHandle(this.ref, this.ctx);

  StudyWordCommand get _studyWordCommand =>
      ref.read(studyWordCommandProvider);
  StudyLogCommand get _studyLogCommand =>
      ref.read(studyLogCommandProvider);
  DailyStatCommand get _dailyStatCommand =>
      ref.read(dailyStatCommandProvider);

  Future<void> submitFirstLearn({
    required int wordId,
    required int durationMs,
  }) async {
    if (durationMs > 0) {
      ctx.addDuration(durationMs);
    }
    ctx.markLearned();

    await _studyWordCommand.markAsLearned(
      userId: ctx.userId,
      wordId: wordId,
    );

    await _studyLogCommand.logFirstLearn(
      userId: ctx.userId,
      wordId: wordId,
      durationMs: durationMs,
    );
  }

  Future<void> submitReview({
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    required ReviewResult reviewResult,
    int algorithm = 1,
  }) async {
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
    if (durationMs > 0) {
      ctx.addDuration(durationMs);
    }

    ctx.markReviewed();
    if (rating <= 1) {
      ctx.markFailed();
    }
  }

  Future<void> flush() async {
    if (_flushed) return;
    _flushed = true;

    await _dailyStatCommand.applySession(
      userId: ctx.userId,
      learned: ctx.learned,
      reviewed: ctx.reviewed,
      failed: ctx.failed,
      mastered: ctx.mastered,
      durationMs: ctx.durationMs,
    );
  }
}
