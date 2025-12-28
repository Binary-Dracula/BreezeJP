import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_log.dart';
import '../study_log_command.dart';
import '../study_word_command.dart';
import 'review_result.dart';
import 'session_lifecycle_guard.dart';
import 'session_scope.dart';
import 'session_stat_policy.dart';

class StudySessionHandle {
  StudySessionHandle({
    required this.userId,
    required this.scope,
    required Ref ref,
  })  : _ref = ref,
        _guard = SessionLifecycleGuard(),
        _accumulator = SessionStatAccumulator();

  final int userId;
  final SessionScope scope;

  final Ref _ref;
  final SessionLifecycleGuard _guard;
  final SessionStatAccumulator _accumulator;

  StudyWordCommand get _studyWordCommand =>
      _ref.read(studyWordCommandProvider);
  StudyLogCommand get _studyLogCommand =>
      _ref.read(studyLogCommandProvider);
  void onFirstLearn({required int durationMs}) {
    _recordEvent(
      SessionEventType.firstLearn,
      durationMs: durationMs,
    );
  }

  void onReviewCorrect({required int durationMs}) {
    _recordEvent(
      SessionEventType.review,
      durationMs: durationMs,
    );
  }

  void onReviewFailed({required int durationMs}) {
    _recordEvent(
      SessionEventType.reviewFailed,
      durationMs: durationMs,
    );
  }

  void onKanaReview({required int durationMs}) {
    _recordEvent(
      SessionEventType.kanaReview,
      durationMs: durationMs,
    );
  }

  Future<void> submitFirstLearn({
    required int wordId,
    required int durationMs,
  }) async {
    onFirstLearn(durationMs: durationMs);

    await _studyWordCommand.markAsLearned(
      userId: userId,
      wordId: wordId,
    );

    await _studyLogCommand.logFirstLearn(
      userId: userId,
      wordId: wordId,
      durationMs: 0,
    );
  }

  Future<void> submitReview({
    required int wordId,
    required ReviewRating rating,
    required int durationMs,
    required ReviewResult reviewResult,
    int algorithm = 1,
  }) async {
    if (rating == ReviewRating.again) {
      onReviewFailed(durationMs: durationMs);
    } else {
      onReviewCorrect(durationMs: durationMs);
    }

    await _studyWordCommand.applyReviewResult(
      userId: userId,
      wordId: wordId,
      isCorrect: rating != ReviewRating.again,
      reviewResult: reviewResult,
    );

    await _studyLogCommand.logReview(
      userId: userId,
      wordId: wordId,
      rating: rating,
      durationMs: 0,
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
    onKanaReview(durationMs: durationMs);
  }

  Future<void> flush() async {
    await _guard.flushOnce(() async {});
  }

  void _recordEvent(
    SessionEventType type, {
    int durationMs = 0,
  }) {
    final delta = SessionStatPolicy.deltaFor(
      type,
      durationMs: durationMs,
    );
    _accumulator.applyDelta(delta);
  }
}
