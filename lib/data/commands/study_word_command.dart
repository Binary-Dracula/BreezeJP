import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/learning_status.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/app_logger.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

final studyWordCommandProvider = Provider<StudyWordCommand>((ref) {
  return StudyWordCommand(ref);
});

/// StudyWord 行为命令层（2.0 — per-book 状态变更）
class StudyWordCommand {
  StudyWordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);

  int get _firstReviewIntervalMinutes => ref.read(firstReviewIntervalProvider);

  /// 翻到即标记为学习中（幂等：已存在则不更新）
  Future<void> markAsLearned({
    required int userId,
    required String wordId,
    required String bookId,
  }) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId, bookId);
      if (existing != null) return; // 已有记录，忽略

      final now = DateTime.now();
      final firstReviewAt = now.add(
        Duration(minutes: _firstReviewIntervalMinutes),
      );
      await _repo.createStudyWord(
        StudyWord(
          id: 0,
          userId: userId,
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.learning,
          nextReviewAt: firstReviewAt,
          lastReviewedAt: now,
          firstLearnedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'null',
        toState: 'learning',
        reason: 'mark_learned',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 标记单词为已掌握
  Future<void> markAsMastered({
    required int userId,
    required String wordId,
    required String bookId,
  }) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId, bookId);
      final now = DateTime.now();

      if (studyWord == null) {
        await _repo.createStudyWord(
          StudyWord(
            id: 0,
            userId: userId,
            wordId: wordId,
            bookId: bookId,
            userState: LearningStatus.mastered,
            firstLearnedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _repo.updateStudyWord(
          studyWord.copyWith(
            userState: LearningStatus.mastered,
            nextReviewAt: null,
            updatedAt: now,
          ),
        );
      }

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: studyWord?.userState.name ?? 'null',
        toState: 'mastered',
        reason: 'mark_mastered',
      );
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
  Future<void> markAsIgnored({
    required int userId,
    required String wordId,
    required String bookId,
  }) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId, bookId);
      final now = DateTime.now();

      if (studyWord == null) {
        await _repo.createStudyWord(
          StudyWord(
            id: 0,
            userId: userId,
            wordId: wordId,
            bookId: bookId,
            userState: LearningStatus.ignored,
            firstLearnedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _repo.updateStudyWord(
          studyWord.copyWith(
            userState: LearningStatus.ignored,
            nextReviewAt: null,
            updatedAt: now,
          ),
        );
      }

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: studyWord?.userState.name ?? 'null',
        toState: 'ignored',
        reason: 'mark_ignored',
      );
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

  /// 批量重置 SRS 参数（SM-2 ↔ FSRS 切换时调用）
  Future<void> resetAlgorithmData(int userId) async {
    await _repo.resetAlgorithmSrsData(userId);
    logger.info('[StudyWordCmd] SRS reset for userId=$userId');
  }

  /// 删除某本书的所有学习记录
  Future<void> deleteAllByBook(int userId, String bookId) async {
    await _repo.deleteAllByBook(userId, bookId);
  }
}
