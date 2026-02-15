import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/study_grammar.dart';
import '../models/study_log.dart';
import '../repositories/study_grammar_repository.dart';
import '../repositories/study_grammar_repository_provider.dart';

final grammarCommandProvider = Provider<GrammarCommand>((ref) {
  return GrammarCommand(ref);
});

class GrammarCommand {
  GrammarCommand(this.ref);

  final Ref ref;

  StudyGrammarRepository get _repo => ref.read(studyGrammarRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);

  /// 获取或创建学习状态 (默认 seen/0)
  Future<StudyGrammar> getOrCreateLearningState(
    int userId,
    int grammarId,
  ) async {
    try {
      final existing = await _repo.getStudyGrammar(userId, grammarId);
      if (existing != null) return existing;

      final now = DateTime.now();
      final state = StudyGrammar(
        id: 0,
        userId: userId,
        grammarId: grammarId,
        learningStatus: LearningStatus.seen.value,
        nextReviewAt: null,
        lastReviewedAt: null,
        interval: 0,
        easeFactor: 2.5,
        stability: 0, // FSRS initial default
        difficulty: 0,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _repo.saveStudyGrammar(state);
      // Re-fetch to get ID if needed, but for now just returning state (ID might be missing if we used replace)
      // If repo.save uses replace without returning ID, we might need to fetch again to be sure.
      // But for StudyGrammar, ID is not super critical if we query by unique key.

      logger.info(
        'Grammar state initialized: userId=$userId grammarId=$grammarId',
      );
      return state;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'study_grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 开始学习 (seen -> learning)
  Future<void> startLearning(int userId, int grammarId) async {
    final existing = await getOrCreateLearningState(userId, grammarId);
    if (existing.learningStatus == LearningStatus.learning.value) return;

    final now = DateTime.now();
    // Initial accumulation using FSRS default parameters for 'Good'
    final algorithmType = AlgorithmType.fsrs;
    final output = _algorithmService.calculate(
      algorithmType: algorithmType,
      input: SRSInput.initial(ReviewRating.good),
    );

    final updated = existing.copyWith(
      learningStatus: LearningStatus.learning.value,
      nextReviewAt: output.nextReviewAt,
      lastReviewedAt: now, // Mark as reviewed now
      interval: output.interval,
      easeFactor: output.easeFactor,
      stability: output.stability,
      difficulty: output.difficulty,
      streak: 1,
      totalReviews: 1,
      updatedAt: now,
    );

    await _repo.saveStudyGrammar(updated);
    logger.info('Grammar marked as learning: $grammarId');
  }

  /// 记录复习结果
  Future<void> onGrammarReviewed({
    required int userId,
    required int grammarId,
    required ReviewRating rating,
  }) async {
    final existing = await _repo.getStudyGrammar(userId, grammarId);
    if (existing == null) {
      logger.warning('Grammar study state not found for review: $grammarId');
      return;
    }

    final now = DateTime.now();

    // Elapsed calculations
    final lastReviewedAt = existing.lastReviewedAt;
    final elapsedSeconds = lastReviewedAt == null
        ? 0
        : now.difference(lastReviewedAt).inSeconds;
    final double elapsedDays = elapsedSeconds <= 0
        ? 0.0
        : elapsedSeconds / 86400.0;

    final input = SRSInput(
      interval: existing.interval,
      easeFactor: existing.easeFactor,
      stability: existing.stability,
      difficulty: existing.difficulty,
      reviews: existing.totalReviews,
      lapses: existing.failCount,
      rating: rating,
      elapsedDays: elapsedDays,
    );

    // Force FSRS for grammar as per freeze.md
    final output = _algorithmService.calculate(
      algorithmType: AlgorithmType.fsrs,
      input: input,
    );

    final totalReviews = existing.totalReviews + 1;
    final failCount = existing.failCount + (rating.isCorrect ? 0 : 1);
    final streak = rating.isCorrect ? existing.streak + 1 : 0;

    final updated = existing.copyWith(
      nextReviewAt: output.nextReviewAt,
      lastReviewedAt: now,
      interval: output.interval,
      easeFactor: output.easeFactor,
      stability: output.stability,
      difficulty: output.difficulty,
      streak: streak,
      totalReviews: totalReviews,
      failCount: failCount,
      updatedAt: now,
    );

    await _repo.saveStudyGrammar(updated);
    logger.info('Grammar reviewed: $grammarId, rating: ${rating.name}');
  }

  /// 标记为已掌握
  Future<void> markAsMastered(int userId, int grammarId) async {
    final existing = await getOrCreateLearningState(userId, grammarId);

    final updated = existing.copyWith(
      learningStatus: LearningStatus.mastered.value,
      nextReviewAt: null, // Clear review schedule
      updatedAt: DateTime.now(),
    );

    await _repo.saveStudyGrammar(updated);
    logger.info('Grammar mastered: $grammarId');
  }
}
