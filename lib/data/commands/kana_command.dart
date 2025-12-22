import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_log.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kana_repository_provider.dart';
import 'session/study_session_handle.dart';

/// Kana command layer (state updates / review results / log writes).
class KanaCommand {
  KanaCommand(this.ref);

  final Ref ref;

  KanaRepository get _repo => ref.read(kanaRepositoryProvider);

  /// Get or create a kana learning state (UNIQUE: user_id + kana_id).
  /// Ensures a baseline record before first learn/review.
  Future<KanaLearningState> getOrCreateLearningState(
    int userId,
    int kanaId,
  ) async {
    try {
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing != null) return existing;

      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final nextReviewAt =
          now.add(const Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000;

      final state = KanaLearningState(
        id: 0,
        userId: userId,
        kanaId: kanaId,
        learningStatus: KanaLearningStatus.learning,
        nextReviewAt: nextReviewAt,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        interval: 0,
        easeFactor: 2.5,
        stability: 0,
        difficulty: 0,
        createdAt: nowSeconds,
        updatedAt: nowSeconds,
      );

      final id = await _repo.insertKanaLearningState(state);
      return state.copyWith(id: id);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark kana as learned.
  Future<void> markKanaAsLearned(int userId, int kanaId) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final existing = await _repo.getKanaLearningState(userId, kanaId);

      if (existing != null) {
        final updated = existing.copyWith(
          learningStatus: KanaLearningStatus.mastered,
          lastReviewedAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _repo.updateKanaLearningState(updated);
      } else {
        final state = KanaLearningState(
          id: 0,
          userId: userId,
          kanaId: kanaId,
          learningStatus: KanaLearningStatus.mastered,
          lastReviewedAt: nowSeconds,
          streak: 0,
          totalReviews: 0,
          failCount: 0,
          interval: 0,
          easeFactor: 2.5,
          stability: 0,
          difficulty: 0,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _repo.insertKanaLearningState(state);
      }

      logger.info('假名标记为已学习: userId=$userId, kanaId=$kanaId');
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Insert a kana log (base CRUD).
  Future<int> addKanaLog(KanaLog log) async {
    try {
      return await _repo.insertKanaLog(log);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create and insert a kana log with common fields.
  Future<int> addKanaLogQuick({
    required int userId,
    required int kanaId,
    required KanaLogType logType,
    int? rating,
    int algorithm = 1,
    double? intervalAfter,
    int? nextReviewAtAfter,
    double? easeFactorAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    String? questionType,
    int durationMs = 0,
    StudySessionHandle? session,
  }) async {
    final log = KanaLog(
      id: 0,
      userId: userId,
      kanaId: kanaId,
      logType: logType,
      rating: rating,
      algorithm: algorithm,
      intervalAfter: intervalAfter,
      nextReviewAtAfter: nextReviewAtAfter,
      easeFactorAfter: easeFactorAfter,
      fsrsStabilityAfter: fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter,
      questionType: questionType,
      durationMs: durationMs,
    );
    final id = await addKanaLog(log);

    if (session != null && logType == KanaLogType.review) {
      session.onKanaReview(durationMs: durationMs);
    }

    return id;
  }

  /// Update only the learning state's updatedAt timestamp.
  Future<void> updateLearningTimestamp(int userId, int kanaId) async {
    try {
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing == null) return;

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final updated = existing.copyWith(updatedAt: nowSeconds);
      await _repo.updateKanaLearningState(updated);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Insert a learning log entry.
  Future<void> insertLearningLog({
    required int userId,
    required int kanaId,
    int durationMs = 0,
  }) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final log = KanaLog(
        id: 0,
        userId: userId,
        kanaId: kanaId,
        logType: KanaLogType.firstLearn,
        durationMs: durationMs,
        algorithm: 1,
        createdAt: nowSeconds,
      );

      await addKanaLog(log);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Insert a review log entry.
  Future<void> insertReviewLog({
    required int userId,
    required int kanaId,
    required int rating,
    required int algorithm,
    required double intervalAfter,
    required int nextReviewAtAfter,
    required double easeFactorAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    String? questionType,
    StudySessionHandle? session,
  }) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final log = KanaLog(
        id: 0,
        userId: userId,
        kanaId: kanaId,
        logType: KanaLogType.review,
        rating: rating,
        algorithm: algorithm,
        intervalAfter: intervalAfter,
        nextReviewAtAfter: nextReviewAtAfter,
        easeFactorAfter: easeFactorAfter,
        fsrsStabilityAfter: fsrsStabilityAfter,
        fsrsDifficultyAfter: fsrsDifficultyAfter,
        durationMs: 0,
        questionType: questionType,
        createdAt: nowSeconds,
      );

      await addKanaLog(log);

      if (session != null) {
        session.onKanaReview(durationMs: 0);
      }
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update kana review result (SRS fields).
  Future<void> updateKanaReviewResult({
    required int userId,
    required int kanaId,
    required int rating,
    required double newInterval,
    required double newEaseFactor,
    required int nextReviewAt,
  }) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing == null) {
        logger.warning('假名学习状态不存在: userId=$userId, kanaId=$kanaId');
        return;
      }

      final isCorrect = rating >= 2;
      final newStreak = isCorrect ? existing.streak + 1 : 0;
      final newFailCount =
          isCorrect ? existing.failCount : existing.failCount + 1;

      final updated = existing.copyWith(
        lastReviewedAt: nowSeconds,
        nextReviewAt: nextReviewAt,
        streak: newStreak,
        totalReviews: existing.totalReviews + 1,
        failCount: newFailCount,
        interval: newInterval,
        easeFactor: newEaseFactor,
        updatedAt: nowSeconds,
      );

      await _repo.updateKanaLearningState(updated);

      logger.info(
        '假名复习结果更新: userId=$userId, kanaId=$kanaId, rating=$rating, interval=$newInterval',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
