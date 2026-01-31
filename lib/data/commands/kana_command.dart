import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/kana/kana_domain_event.dart';
import '../models/kana_learning_state.dart';
import '../models/study_log.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kana_repository_provider.dart';

/// Kana command layer (state updates only).
class KanaCommand {
  KanaCommand(this.ref);

  final Ref ref;

  KanaRepository get _repo => ref.read(kanaRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);

  /// Create kana learning state when first practiced.
  Future<KanaPracticed?> onKanaPracticed({
    required int userId,
    required int kanaId,
  }) async {
    try {
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing != null) return null;

      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final output = _algorithmService.calculate(
        algorithmType: _algorithmService.defaultAlgorithm,
        input: SRSInput.initial(ReviewRating.good),
      );
      final state = KanaLearningState(
        id: 0,
        userId: userId,
        kanaId: kanaId,
        learningStatus: LearningStatus.learning,
        nextReviewAt: output.nextReviewAt.millisecondsSinceEpoch ~/ 1000,
        interval: output.interval,
        easeFactor: output.easeFactor,
        stability: output.stability,
        difficulty: output.difficulty,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: nowSeconds,
        updatedAt: nowSeconds,
      );
      await _repo.insertKanaLearningState(state);
      return KanaPracticed(userId: userId, kanaId: kanaId, occurredAt: now);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Apply kana review result to SRS fields.
  Future<void> onKanaReviewed({
    required int userId,
    required int kanaId,
    required ReviewRating rating,
    AlgorithmType? algorithmType,
  }) async {
    try {
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      final resolvedAlgorithm =
          algorithmType ?? _algorithmService.defaultAlgorithm;

      SRSInput input;
      if (existing == null) {
        input = SRSInput.initial(rating);
      } else {
        final lastReviewedAt = existing.lastReviewedAt;
        final elapsedSeconds = lastReviewedAt == null
            ? 0
            : nowSeconds - lastReviewedAt;
        final double elapsedDays = elapsedSeconds <= 0
            ? 0.0
            : elapsedSeconds / 86400.0;
        input = SRSInput(
          interval: existing.interval,
          easeFactor: existing.easeFactor == 0
              ? AppConstants.defaultEaseFactor
              : existing.easeFactor,
          stability: existing.stability,
          difficulty: existing.difficulty,
          reviews: existing.totalReviews,
          lapses: existing.failCount,
          rating: rating,
          elapsedDays: elapsedDays,
        );
      }

      final output = _algorithmService.calculate(
        algorithmType: resolvedAlgorithm,
        input: input,
      );

      final totalReviews = (existing?.totalReviews ?? 0) + 1;
      final failCount = (existing?.failCount ?? 0) + (rating.isCorrect ? 0 : 1);
      final streak = rating.isCorrect ? (existing?.streak ?? 0) + 1 : 0;
      final nextReviewAt = output.nextReviewAt.millisecondsSinceEpoch ~/ 1000;
      final baseStatus = existing?.learningStatus ?? LearningStatus.learning;

      final updated = KanaLearningState(
        id: existing?.id ?? 0,
        userId: userId,
        kanaId: kanaId,
        learningStatus: baseStatus == LearningStatus.seen
            ? LearningStatus.learning
            : baseStatus,
        nextReviewAt: nextReviewAt,
        lastReviewedAt: nowSeconds,
        interval: output.interval,
        easeFactor: output.easeFactor,
        stability: output.stability,
        difficulty: output.difficulty,
        streak: streak,
        totalReviews: totalReviews,
        failCount: failCount,
        createdAt: existing?.createdAt ?? nowSeconds,
        updatedAt: nowSeconds,
      );

      if (existing == null) {
        await _repo.insertKanaLearningState(updated);
      } else {
        await _repo.updateKanaLearningState(updated);
      }
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

  /// Toggle kana status between learning and mastered.
  Future<KanaDomainEvent?> toggleKanaMastered({
    required int userId,
    required int kanaId,
  }) async {
    try {
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final existing = await _repo.getKanaLearningState(userId, kanaId);
      if (existing == null) {
        final state = KanaLearningState(
          id: 0,
          userId: userId,
          kanaId: kanaId,
          learningStatus: LearningStatus.mastered,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _repo.insertKanaLearningState(state);
        return KanaMastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }

      if (existing.learningStatus == LearningStatus.mastered) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.learning,
          updatedAt: nowSeconds,
        );
        await _repo.updateKanaLearningState(updated);
        return KanaUnmastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }

      if (existing.learningStatus == LearningStatus.learning) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.mastered,
          updatedAt: nowSeconds,
        );
        await _repo.updateKanaLearningState(updated);
        return KanaMastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }
      return null;
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
