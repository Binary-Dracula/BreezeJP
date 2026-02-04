import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../study_log_command.dart';
import '../study_word_command.dart';
import 'session_lifecycle_guard.dart';
import 'session_scope.dart';
import 'session_stat_policy.dart';

class StudySessionHandle {
  StudySessionHandle({
    required this.userId,
    required this.scope,
    required Ref ref,
  }) : _ref = ref,
       _guard = SessionLifecycleGuard(),
       _accumulator = SessionStatAccumulator();

  final int userId;
  final SessionScope scope;

  final Ref _ref;
  final SessionLifecycleGuard _guard;
  final SessionStatAccumulator _accumulator;

  StudyWordCommand get _studyWordCommand => _ref.read(studyWordCommandProvider);
  StudyLogCommand get _studyLogCommand => _ref.read(studyLogCommandProvider);
  void onFirstLearn() {
    _recordEvent(SessionEventType.firstLearn);
  }

  void onReviewCorrect() {
    _recordEvent(SessionEventType.review);
  }

  void onReviewFailed() {
    _recordEvent(SessionEventType.reviewFailed);
  }

  void onKanaReview() {
    _recordEvent(SessionEventType.kanaReview);
  }

  Future<void> submitFirstLearn({required int wordId}) async {
    onFirstLearn();

    await _studyWordCommand.markAsLearned(userId: userId, wordId: wordId);
  }

  Future<void> submitKanaReview({required int rating}) async {
    onKanaReview();
  }

  Future<void> flush() async {
    await _guard.flushOnce(() async {});
  }

  void _recordEvent(SessionEventType type) {
    final delta = SessionStatPolicy.deltaFor(type);
    _accumulator.applyDelta(delta);
  }
}
