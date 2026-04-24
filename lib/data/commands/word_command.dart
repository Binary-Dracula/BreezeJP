import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/log_formatter.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

final wordCommandProvider = Provider<WordCommand>((ref) {
  return WordCommand(ref);
});

/// Word 行为命令层（SRS 复习更新）
class WordCommand {
  WordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);

  /// 记录一次复习并更新 SRS 状态。
  Future<void> onWordReviewed({
    required int userId,
    required String wordId,
    required String bookId,
    required ReviewRating rating,
    AlgorithmType? algorithmType,
  }) async {
    final existing = await _repo.getStudyWord(userId, wordId, bookId);
    if (existing == null) {
      logger.warning(
        '单词学习状态不存在: userId=$userId, wordId=$wordId, bookId=$bookId',
      );
      return;
    }
    if (existing.userState != LearningStatus.learning) {
      logger.warning(
        '[WordState] ignore review: wordId=$wordId state=${existing.userState.name}',
      );
      return;
    }

    final now = DateTime.now();
    final resolvedAlgorithm =
        algorithmType ?? _algorithmService.defaultAlgorithm;
    final lastReviewedAt = existing.lastReviewedAt;
    final elapsedSeconds = lastReviewedAt == null
        ? 0
        : now.difference(lastReviewedAt).inSeconds;
    final double elapsedDays = elapsedSeconds <= 0
        ? 0.0
        : elapsedSeconds / 86400.0;

    final input = SRSInput(
      interval: (existing.interval ?? 0).toDouble(),
      easeFactor: existing.easeFactor ?? AppConstants.defaultEaseFactor,
      stability: existing.stability ?? 0,
      difficulty: existing.difficulty ?? 0,
      reviews: existing.totalReviews,
      lapses: existing.failCount,
      rating: rating,
      elapsedDays: elapsedDays,
    );
    final output = _algorithmService.calculate(
      algorithmType: resolvedAlgorithm,
      input: input,
    );

    final totalReviews = existing.totalReviews + 1;
    final failCount = existing.failCount + (rating.isCorrect ? 0 : 1);
    final streak = rating.isCorrect ? existing.streak + 1 : 0;

    final updated = existing.copyWith(
      nextReviewAt: output.nextReviewAt,
      lastReviewedAt: now,
      interval: output.interval.round(),
      easeFactor: output.easeFactor,
      stability: output.stability,
      difficulty: output.difficulty,
      streak: streak,
      totalReviews: totalReviews,
      failCount: failCount,
      updatedAt: now,
    );

    await _repo.updateStudyWord(updated);
    logger.srsUpdate(
      scope: 'word',
      userId: userId,
      itemId: wordId,
      rating: rating,
      algorithmType: resolvedAlgorithm,
      before: _srsSnapshot(existing),
      after: _srsSnapshot(updated),
    );
  }

  Map<String, dynamic> _srsSnapshot(StudyWord word) {
    return {
      'interval': word.interval,
      'ef': word.easeFactor,
      'stability': word.stability,
      'difficulty': word.difficulty,
      'nextReview': word.nextReviewAt != null
          ? LogFormatter.formatTimestamp(word.nextReviewAt!)
          : null,
      'lastReview': word.lastReviewedAt != null
          ? LogFormatter.formatTimestamp(word.lastReviewedAt!)
          : null,
      'streak': word.streak,
      'totalReviews': word.totalReviews,
      'failCount': word.failCount,
    };
  }
}
