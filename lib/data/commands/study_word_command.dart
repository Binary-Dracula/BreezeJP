import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';
import 'session/review_result.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

final studyWordCommandProvider = Provider<StudyWordCommand>((ref) {
  return StudyWordCommand(ref);
});

/// StudyWord 行为命令层（状态变更 / SRS）
class StudyWordCommand {
  StudyWordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);

  /// 记录复习结果（答对）
  Future<void> submitCorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    final nextReview = DateTime.now().add(
      Duration(days: newInterval.ceil()),
    );
    await applyReviewResult(
      userId: userId,
      wordId: wordId,
      isCorrect: true,
      reviewResult: ReviewResult(
        intervalAfter: newInterval,
        easeFactorAfter: newEaseFactor,
        nextReviewAtAfter: nextReview,
        fsrsStabilityAfter: newStability,
        fsrsDifficultyAfter: newDifficulty,
      ),
    );
  }

  /// 记录复习结果（答错）
  Future<void> submitIncorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    final nextReview = DateTime.now().add(
      Duration(days: newInterval.ceil()),
    );
    await applyReviewResult(
      userId: userId,
      wordId: wordId,
      isCorrect: false,
      reviewResult: ReviewResult(
        intervalAfter: newInterval,
        easeFactorAfter: newEaseFactor,
        nextReviewAtAfter: nextReview,
        fsrsStabilityAfter: newStability,
        fsrsDifficultyAfter: newDifficulty,
      ),
    );
  }

  Future<void> applyReviewResult({
    required int userId,
    required int wordId,
    required bool isCorrect,
    required ReviewResult reviewResult,
  }) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final now = DateTime.now();
      final updated = studyWord.copyWith(
        userState: UserWordState.learning,
        lastReviewedAt: now,
        nextReviewAt: reviewResult.nextReviewAtAfter,
        interval: reviewResult.intervalAfter,
        easeFactor: reviewResult.easeFactorAfter,
        stability: reviewResult.fsrsStabilityAfter ?? studyWord.stability,
        difficulty: reviewResult.fsrsDifficultyAfter ?? studyWord.difficulty,
        streak: isCorrect ? studyWord.streak + 1 : 0,
        totalReviews: studyWord.totalReviews + 1,
        failCount: isCorrect ? studyWord.failCount : studyWord.failCount + 1,
        updatedAt: now,
      );

      await _repo.updateStudyWord(updated);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 标记单词为已掌握
  Future<void> markAsMastered(int userId, int wordId) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.mastered,
        updatedAt: DateTime.now(),
      );

      await _repo.updateStudyWord(updated);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 标记单词为忽略
  Future<void> markAsIgnored(int userId, int wordId) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.ignored,
        updatedAt: DateTime.now(),
      );

      await _repo.updateStudyWord(updated);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 重置单词学习进度
  Future<void> resetProgress(int userId, int wordId) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final now = DateTime.now();
      final updated = studyWord.copyWith(
        userState: UserWordState.newWord,
        nextReviewAt: null,
        lastReviewedAt: null,
        interval: 0,
        easeFactor: 2.5,
        stability: 0,
        difficulty: 0,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        updatedAt: now,
      );

      await _repo.updateStudyWord(updated);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 标记单词为学习中（user_state = 1）
  /// 如果记录不存在则创建，存在则更新
  Future<void> markAsLearned({required int userId, required int wordId}) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
      final now = DateTime.now();

      if (studyWord == null) {
        final newRecord = StudyWord(
          id: 0,
          userId: userId,
          wordId: wordId,
          userState: UserWordState.learning,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.createStudyWord(newRecord);
        logger.info('标记单词为学习中: userId=$userId wordId=$wordId');
        return;
      }

      if (studyWord.userState == UserWordState.mastered) {
        return;
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.learning,
        updatedAt: now,
      );

      await _repo.updateStudyWord(updated);
      logger.info('标记单词为学习中: userId=$userId wordId=$wordId');
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

}
