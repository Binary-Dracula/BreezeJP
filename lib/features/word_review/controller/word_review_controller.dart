import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/algorithm/srs_types.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/review_session_remote_command.dart';
import '../../../data/commands/word_command.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/study_remote_query.dart';
import '../../../data/queries/study_remote_query_provider.dart';

import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

final wordReviewControllerProvider =
    NotifierProvider<WordReviewController, WordReviewState>(
      WordReviewController.new,
    );

class WordReviewController extends Notifier<WordReviewState> {
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyRemoteQuery get _studyRemoteQuery => ref.read(studyRemoteQueryProvider);
  ReviewSessionRemoteCommand get _reviewSessionRemoteCommand =>
      ref.read(reviewSessionRemoteCommandProvider);
  WordCommand get _wordCommand => ref.read(wordCommandProvider);

  @override
  WordReviewState build() => const WordReviewState();

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  void _setSessionBootstrapState({
    required bool isLoading,
    required bool isEmpty,
  }) {
    state = state.copyWith(
      sessionId: null,
      isLoading: isLoading,
      isEmpty: isEmpty,
      items: const [],
      currentIndex: 0,
      currentPhase: ReviewCardPhase.testing,
      hasMistakeOnCurrent: false,
      currentOptions: const [],
      isAllFinished: false,
      error: null,
      isNetworkError: false,
    );
  }

  Future<void> loadReview() async {
    try {
      _setSessionBootstrapState(isLoading: true, isEmpty: false);

      final user = await _getActiveUser();
      final remoteSession = await _studyRemoteQuery.fetchWordReviewSession(
        localUserId: user.id,
      );
      final items = remoteSession.items
          .map(
            (item) => WordReviewItem(
              studyWord: item.studyWord,
              wordDetail: item.wordDetail,
              questionType: wordReviewQuestionTypeFromApi(item.questionType),
              audioSource: item.audioSource,
              meaning: item.meaning,
              reading: item.reading,
              options: item.options,
              clozeSentence: item.clozeSentence,
            ),
          )
          .toList();
      if (items.isEmpty) {
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        logger.info('No due words for review.');
        return;
      }

      final safeIndex = _resolveSafeCurrentIndex(
        remoteSession.currentIndex,
        items.length,
      );

      logger.info('Resume remote word review session: ${items.length} items');

      state = state.copyWith(
        sessionId: remoteSession.sessionId,
        isLoading: false,
        isEmpty: false,
        items: items,
        currentIndex: safeIndex,
        currentPhase: _reviewCardPhaseFromApi(remoteSession.currentPhase),
        hasMistakeOnCurrent: remoteSession.hasMistakeOnCurrent,
        isAllFinished: false,
        error: null,
      );

      await _prepareCurrentCardOptions();
    } catch (e, stackTrace) {
      logger.error('Start word review failed', e, stackTrace);
      final isNetworkError = e is NetworkException;
      state = state.copyWith(
        isLoading: false,
        error: isNetworkError ? null : e.toString(),
        isNetworkError: isNetworkError,
      );
    }
  }

  /// 为当前卡片生成选项并记录答题开始时间
  Future<void> _prepareCurrentCardOptions() async {
    final item = state.currentItem;
    if (item == null) return;
    state = state.copyWith(
      currentOptions: item.options,
      cardStartTime: DateTime.now(),
    );
  }

  /// 根据答题耗时（秒）自动推导评分：≤4s → easy，5–10s → good，>10s → hard
  ReviewRating _ratingFromElapsed(double elapsedSeconds) {
    if (elapsedSeconds <= 4) return ReviewRating.easy;
    if (elapsedSeconds <= 10) return ReviewRating.good;
    return ReviewRating.hard;
  }

  /// 用户在客观测试中选择了某个选项
  Future<void> submitObjectiveAnswer(String selectedOption) async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.testing) return;

    String correctOption = '';
    switch (item.questionType) {
      case WordReviewQuestionType.wordToMeaning:
      case WordReviewQuestionType.audioToMeaning:
        correctOption = item.meaning ?? 'Unknown';
        break;
      case WordReviewQuestionType.kanjiToReading:
      case WordReviewQuestionType.meaningToSpelling:
        correctOption = item.reading ?? '';
        break;
      case WordReviewQuestionType.clozeTest:
        correctOption = item.wordDetail.word.word;
        break;
    }

    final isCorrect = selectedOption == correctOption;

    if (isCorrect) {
      // 根据答题耗时自动评分（无需用户手动选 Hard/Good/Easy）
      if (!state.hasMistakeOnCurrent) {
        final elapsed = state.cardStartTime != null
            ? DateTime.now().difference(state.cardStartTime!).inMilliseconds /
                  1000.0
            : 5.0;
        final autoRating = _ratingFromElapsed(elapsed);
        try {
          await _wordCommand.onWordReviewed(
            userId: item.studyWord.userId,
            wordId: item.studyWord.wordId,
            bookId: item.studyWord.bookId,
            rating: autoRating,
          );
        } catch (e, stackTrace) {
          logger.error('Failed to log auto rating', e, stackTrace);
        }
      }
      state = state.copyWith(currentPhase: ReviewCardPhase.grading);
      await _persistCurrentSession();
    } else {
      if (!state.hasMistakeOnCurrent) {
        state = state.copyWith(hasMistakeOnCurrent: true);

        try {
          await _wordCommand.onWordReviewed(
            userId: item.studyWord.userId,
            wordId: item.studyWord.wordId,
            bookId: item.studyWord.bookId,
            rating: ReviewRating.again,
          );
        } catch (e, stackTrace) {
          logger.error('Failed to log again rating', e, stackTrace);
        }
        await _persistCurrentSession();
      }
    }
  }

  /// 用户在答案展示阶段点击「继续」前进下一题
  Future<void> continueToNext() async {
    final item = state.currentItem;
    if (item == null || state.currentPhase != ReviewCardPhase.grading) return;
    await _goToNextCard();
  }

  Future<void> _goToNextCard() async {
    final items = List<WordReviewItem>.from(state.items);
    if (state.hasMistakeOnCurrent) {
      final currentItem = items[state.currentIndex];
      items.add(currentItem);
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= items.length) {
      state = state.copyWith(
        isAllFinished: true,
        items: items,
        currentIndex: nextIndex,
      );
      await _completeCurrentSession();
    } else {
      state = state.copyWith(
        items: items,
        currentIndex: nextIndex,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
      );
      await _prepareCurrentCardOptions();
      await _persistCurrentSession();
    }
  }

  Future<void> finishAll() async {
    state = state.copyWith(isLoading: false, isAllFinished: true);
    await _completeCurrentSession();
  }

  Future<void> endSession() async {
    if (state.sessionId == null) {
      return;
    }
    if (state.isAllFinished) {
      await _completeCurrentSession();
      return;
    }
    if (state.items.isEmpty || state.isEmpty) {
      return;
    }
    await _persistCurrentSession();
  }

  Future<void> _persistCurrentSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    await _reviewSessionRemoteCommand.saveWordSession(
      sessionId: sessionId,
      state: state,
    );
  }

  Future<void> _completeCurrentSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    await _reviewSessionRemoteCommand.completeWordSession(
      sessionId: sessionId,
      state: state,
    );
    state = state.copyWith(sessionId: null);
  }

  int _resolveSafeCurrentIndex(int currentIndex, int itemCount) {
    if (itemCount <= 0) {
      return 0;
    }
    if (currentIndex < 0) {
      return 0;
    }
    if (currentIndex >= itemCount) {
      return itemCount - 1;
    }
    return currentIndex;
  }

  ReviewCardPhase _reviewCardPhaseFromApi(String value) {
    return ReviewCardPhase.values.firstWhere(
      (phase) => phase.name == value,
      orElse: () => ReviewCardPhase.testing,
    );
  }
}
