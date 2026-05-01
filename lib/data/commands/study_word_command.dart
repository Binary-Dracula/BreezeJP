import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/learning_status.dart';
import '../../core/providers/home_summary_invalidation_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/app_logger.dart';
import 'sync_remote_command.dart';
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
  SyncRemoteCommand get _syncRemote => ref.read(syncRemoteCommandProvider);
  HomeSummaryInvalidationNotifier get _homeSummaryInvalidation =>
      ref.read(homeSummaryInvalidationProvider.notifier);

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
      final created = await _repo.getStudyWord(userId, wordId, bookId);

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'null',
        toState: 'learning',
        reason: 'mark_learned',
      );

      if (created != null) {
        _homeSummaryInvalidation.markStale();
        unawaited(_pushWordState(created, 'mark_learned'));
      }
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

  /// 将已有记录恢复为学习中。
  Future<void> restoreToLearning({
    required int userId,
    required String wordId,
    required String bookId,
  }) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId, bookId);
      if (existing == null) {
        await markAsLearned(userId: userId, wordId: wordId, bookId: bookId);
        return;
      }

      if (existing.userState == LearningStatus.learning) {
        return;
      }

      final now = DateTime.now();
      final firstReviewAt = now.add(
        Duration(minutes: _firstReviewIntervalMinutes),
      );
      final updated = existing.copyWith(
        userState: LearningStatus.learning,
        nextReviewAt: firstReviewAt,
        lastReviewedAt: now,
        firstLearnedAt: existing.firstLearnedAt ?? now,
        updatedAt: now,
      );

      await _repo.updateStudyWord(updated);
      _homeSummaryInvalidation.markStale();
      unawaited(_pushWordState(updated, 'mark_learned'));

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: existing.userState.name,
        toState: 'learning',
        reason: 'restore_learning',
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
        final created = StudyWord(
          id: 0,
          userId: userId,
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.mastered,
          firstLearnedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.createStudyWord(created);
        final saved = await _repo.getStudyWord(userId, wordId, bookId);
        if (saved != null) {
          _homeSummaryInvalidation.markStale();
          unawaited(_pushWordState(saved, 'mark_mastered'));
        }
      } else {
        final updated = studyWord.copyWith(
          userState: LearningStatus.mastered,
          nextReviewAt: null,
          updatedAt: now,
        );
        await _repo.updateStudyWord(updated);
        _homeSummaryInvalidation.markStale();
        unawaited(_pushWordState(updated, 'mark_mastered'));
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
        final created = StudyWord(
          id: 0,
          userId: userId,
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.ignored,
          firstLearnedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.createStudyWord(created);
        final saved = await _repo.getStudyWord(userId, wordId, bookId);
        if (saved != null) {
          _homeSummaryInvalidation.markStale();
          unawaited(_pushWordState(saved, 'mark_ignored'));
        }
      } else {
        final updated = studyWord.copyWith(
          userState: LearningStatus.ignored,
          nextReviewAt: null,
          updatedAt: now,
        );
        await _repo.updateStudyWord(updated);
        _homeSummaryInvalidation.markStale();
        unawaited(_pushWordState(updated, 'mark_ignored'));
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
    _homeSummaryInvalidation.markStale();
  }

  Future<void> _pushWordState(StudyWord state, String operation) async {
    try {
      await _syncRemote.pushWordState(state: state, operation: operation);
    } catch (e, stackTrace) {
      logger.warning('单词状态已写本地，云端同步稍后重试: ${state.wordId}');
      logger.error('单词状态同步失败', e, stackTrace);
    }
  }
}
