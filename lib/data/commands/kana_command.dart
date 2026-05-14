import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/providers/home_summary_invalidation_provider.dart';
import '../../core/providers/kana_state_cache_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/log_formatter.dart';
import '../../core/domain/kana_domain_event.dart';
import 'kana_remote_command.dart';
import 'kana_remote_command_provider.dart';
import '../models/kana_learning_state.dart';

/// Kana command layer (state updates only).
class KanaCommand {
  KanaCommand(this.ref);

  final Ref ref;

  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);
  KanaRemoteCommand get _remoteCommand => ref.read(kanaRemoteCommandProvider);
  KanaStateCacheNotifier get _kanaStateCache =>
      ref.read(kanaStateCacheProvider.notifier);
  HomeSummaryInvalidationNotifier get _homeSummaryInvalidation =>
      ref.read(homeSummaryInvalidationProvider.notifier);

  KanaLearningState? _getCachedState(int kanaId) {
    return ref.read(kanaStateCacheProvider)[kanaId];
  }

  /// Create kana learning state when first practiced.
  Future<KanaPracticed?> onKanaPracticed({
    required int userId,
    required int kanaId,
  }) async {
    try {
      final existing = _getCachedState(kanaId);
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
      await _persistState(state);
      logger.stateChange(
        scope: 'kana',
        userId: userId,
        itemId: kanaId,
        fromState: 'null',
        toState: 'learning',
        reason: 'practice',
      );
      return KanaPracticed(userId: userId, kanaId: kanaId, occurredAt: now);
    } catch (e, stackTrace) {
      logger.error('更新假名练习状态失败', e, stackTrace);
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
      final existing = _getCachedState(kanaId);
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
        learningStatus: baseStatus == LearningStatus.learning
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

      await _persistState(updated);
      logger.srsUpdate(
        scope: 'kana',
        userId: userId,
        itemId: kanaId,
        rating: rating,
        algorithmType: resolvedAlgorithm,
        before: existing == null ? const {} : _srsSnapshot(existing),
        after: _srsSnapshot(updated),
      );
    } catch (e, stackTrace) {
      logger.error('写回假名复习状态失败', e, stackTrace);
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
      final existing = _getCachedState(kanaId);
      if (existing == null) {
        final state = KanaLearningState(
          id: 0,
          userId: userId,
          kanaId: kanaId,
          learningStatus: LearningStatus.mastered,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _persistState(state);
        logger.stateChange(
          scope: 'kana',
          userId: userId,
          itemId: kanaId,
          fromState: 'null',
          toState: 'mastered',
          reason: 'toggle_mastered',
        );
        return KanaMastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }

      if (existing.learningStatus == LearningStatus.mastered) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.learning,
          updatedAt: nowSeconds,
        );
        await _persistState(updated);
        logger.stateChange(
          scope: 'kana',
          userId: userId,
          itemId: kanaId,
          fromState: 'mastered',
          toState: 'learning',
          reason: 'toggle_mastered',
        );
        return KanaUnmastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }

      if (existing.learningStatus == LearningStatus.learning) {
        final updated = existing.copyWith(
          learningStatus: LearningStatus.mastered,
          updatedAt: nowSeconds,
        );
        await _persistState(updated);
        logger.stateChange(
          scope: 'kana',
          userId: userId,
          itemId: kanaId,
          fromState: 'learning',
          toState: 'mastered',
          reason: 'toggle_mastered',
        );
        return KanaMastered(userId: userId, kanaId: kanaId, occurredAt: now);
      }
      return null;
    } catch (e, stackTrace) {
      logger.error('切换假名掌握状态失败', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _persistState(KanaLearningState state) async {
    await _remoteCommand.saveState(_toRemoteState(state));
    _kanaStateCache.upsertState(state);
    _homeSummaryInvalidation.markStale();
  }

  KanaStateUpsert _toRemoteState(KanaLearningState state) {
    return KanaStateUpsert(
      kanaId: state.kanaId,
      learningStatus: state.learningStatus.value,
      nextReviewAt: state.nextReviewAt,
      lastReviewedAt: state.lastReviewedAt,
      streak: state.streak,
      totalReviews: state.totalReviews,
      failCount: state.failCount,
      interval: state.interval,
      easeFactor: state.easeFactor,
      stability: state.stability,
      difficulty: state.difficulty,
    );
  }

  Map<String, dynamic> _srsSnapshot(KanaLearningState state) {
    return {
      'interval': state.interval,
      'ef': state.easeFactor,
      'stability': state.stability,
      'difficulty': state.difficulty,
      'nextReview': state.nextReviewAt != null
          ? LogFormatter.formatTimestamp(
              DateTime.fromMillisecondsSinceEpoch(state.nextReviewAt! * 1000),
            )
          : null,
      'lastReview': state.lastReviewedAt != null
          ? LogFormatter.formatTimestamp(
              DateTime.fromMillisecondsSinceEpoch(state.lastReviewedAt! * 1000),
            )
          : null,
      'streak': state.streak,
      'totalReviews': state.totalReviews,
      'failCount': state.failCount,
    };
  }
}
