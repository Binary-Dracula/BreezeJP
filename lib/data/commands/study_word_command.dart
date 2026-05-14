import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/learning_status.dart';
import '../../core/providers/home_summary_invalidation_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/app_logger.dart';
import 'word_remote_command.dart';
import 'word_remote_command_provider.dart';

final studyWordCommandProvider = Provider<StudyWordCommand>((ref) {
  return StudyWordCommand(ref);
});

/// StudyWord 行为命令层（2.0 — per-book 状态变更）
class StudyWordCommand {
  StudyWordCommand(this.ref);

  final Ref ref;

  WordRemoteCommand get _remoteCommand => ref.read(wordRemoteCommandProvider);
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
      final now = DateTime.now();
      final firstReviewAt = now.add(
        Duration(minutes: _firstReviewIntervalMinutes),
      );
      await _saveState(
        WordStateUpsert(
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.learning.value,
          nextReviewAt: _toEpochSeconds(firstReviewAt),
          lastReviewedAt: _toEpochSeconds(now),
          firstLearnedAt: _toEpochSeconds(now),
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
      logger.error('标记单词为学习中失败', e, stackTrace);
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
      final now = DateTime.now();
      final firstReviewAt = now.add(
        Duration(minutes: _firstReviewIntervalMinutes),
      );
      await _saveState(
        WordStateUpsert(
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.learning.value,
          nextReviewAt: _toEpochSeconds(firstReviewAt),
          lastReviewedAt: _toEpochSeconds(now),
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'mastered_or_ignored',
        toState: 'learning',
        reason: 'restore_learning',
      );
    } catch (e, stackTrace) {
      logger.error('恢复单词为学习中失败', e, stackTrace);
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
      await _saveState(
        WordStateUpsert(
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.mastered.value,
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'learning_or_ignored_or_null',
        toState: 'mastered',
        reason: 'mark_mastered',
      );
    } catch (e, stackTrace) {
      logger.error('标记单词为已掌握失败', e, stackTrace);
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
      await _saveState(
        WordStateUpsert(
          wordId: wordId,
          bookId: bookId,
          userState: LearningStatus.ignored.value,
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'learning_or_mastered_or_null',
        toState: 'ignored',
        reason: 'mark_ignored',
      );
    } catch (e, stackTrace) {
      logger.error('标记单词为已忽略失败', e, stackTrace);
      rethrow;
    }
  }

  /// 批量重置 SRS 参数（SM-2 ↔ FSRS 切换时调用）
  Future<void> resetAlgorithmData(int userId) async {
    logger.info(
      '[StudyWordCmd] SRS reset skipped for remote-only state, userId=$userId',
    );
  }

  /// 删除某本书的所有学习记录
  Future<void> deleteAllByBook(int userId, String bookId) async {
    logger.info(
      '[StudyWordCmd] deleteAllByBook skipped for remote-only state, userId=$userId, bookId=$bookId',
    );
    _homeSummaryInvalidation.markStale();
  }

  Future<void> _saveState(WordStateUpsert state) async {
    await _remoteCommand.saveState(state);
    _homeSummaryInvalidation.markStale();
  }

  int? _toEpochSeconds(DateTime? value) {
    return value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
  }
}
