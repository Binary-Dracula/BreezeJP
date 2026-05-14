import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/algorithm/srs_types.dart';
import '../../../core/providers/home_summary_invalidation_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/review_session_remote_command.dart';
import '../../../data/models/learning_session.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/study_remote_query.dart';
import '../../../data/queries/study_remote_query_provider.dart';
import '../../../data/repositories/learning_session_repository.dart';
import '../../../data/repositories/learning_session_repository_provider.dart';
import '../../review/shared/review_session_codec.dart';

import '../state/word_review_item.dart';
import '../state/word_review_state.dart';

final wordReviewControllerProvider =
    NotifierProvider<WordReviewController, WordReviewState>(
      WordReviewController.new,
    );

class WordReviewController extends Notifier<WordReviewState> {
  static const _sessionTtl = Duration(days: 7);

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyRemoteQuery get _studyRemoteQuery => ref.read(studyRemoteQueryProvider);
  ReviewSessionRemoteCommand get _reviewSessionRemoteCommand =>
      ref.read(reviewSessionRemoteCommandProvider);
  LearningSessionRepository get _sessionRepo =>
      ref.read(learningSessionRepositoryProvider);
  HomeSummaryInvalidationNotifier get _homeSummaryInvalidation =>
      ref.read(homeSummaryInvalidationProvider.notifier);

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
      localSessionId: null,
      sessionId: null,
      sessionCreatedAt: null,
      isLoading: isLoading,
      isEmpty: isEmpty,
      initialItems: const [],
      items: const [],
      answeredResults: const [],
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
      final restored = await _restoreLocalSession(user);
      if (restored) {
        return;
      }

      final remoteSession = await _studyRemoteQuery.createWordReviewSession(
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

      final remoteSessionId = remoteSession.sessionId;
      if (remoteSessionId == null || remoteSessionId.isEmpty) {
        throw StateError('Remote word review session id is missing');
      }

      final localSession = LearningSession.wordReview(
        userId: user.id,
        serverSessionId: remoteSessionId,
        dataPayload: encodeWordReviewSessionPayload(
          initialItems: items,
          dynamicQueue: items,
          answeredResults: const [],
          currentIndex: 0,
        ),
      );
      final localSessionId = await _sessionRepo.createSession(localSession);

      logger.info('Create remote word review session: ${items.length} items');

      state = state.copyWith(
        localSessionId: localSessionId,
        sessionId: remoteSessionId,
        sessionCreatedAt: localSession.createdAt,
        isLoading: false,
        isEmpty: false,
        initialItems: items,
        items: items,
        answeredResults: const [],
        currentIndex: 0,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
        isAllFinished: false,
        error: null,
        isNetworkError: false,
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

  Future<bool> _restoreLocalSession(User user) async {
    final session = await _sessionRepo.getActiveSessionByType(
      user.id,
      LearningSessionType.wordReview,
    );
    if (session == null) {
      return false;
    }

    if (_isSessionExpired(session.createdAt)) {
      await _sessionRepo.deleteSession(session.id);
      return false;
    }

    final snapshot = decodeWordReviewSessionPayload(session.dataPayload);
    if (snapshot.dynamicQueue.isEmpty || session.serverSessionId == null) {
      await _sessionRepo.deleteSession(session.id);
      return false;
    }

    if (snapshot.currentIndex >= snapshot.dynamicQueue.length) {
      state = state.copyWith(
        localSessionId: session.id,
        sessionId: session.serverSessionId,
        sessionCreatedAt: session.createdAt,
        isLoading: false,
        isEmpty: false,
        initialItems: snapshot.initialItems,
        items: snapshot.dynamicQueue,
        answeredResults: snapshot.answeredResults,
        currentIndex: snapshot.currentIndex,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
        currentOptions: const [],
        cardStartTime: null,
        isAllFinished: true,
        error: null,
        isNetworkError: false,
      );

      final completed = await _completeCurrentSession(
        autoRestartOnStale: false,
      );
      if (completed) {
        await loadReview();
      }
      return true;
    }

    final safeIndex = _resolveSafeCurrentIndex(
      snapshot.currentIndex,
      snapshot.dynamicQueue.length,
    );

    logger.info(
      'Resume local word review session: ${snapshot.dynamicQueue.length} items',
    );

    state = state.copyWith(
      localSessionId: session.id,
      sessionId: session.serverSessionId,
      sessionCreatedAt: session.createdAt,
      isLoading: false,
      isEmpty: false,
      initialItems: snapshot.initialItems,
      items: snapshot.dynamicQueue,
      answeredResults: snapshot.answeredResults,
      currentIndex: safeIndex,
      currentPhase: ReviewCardPhase.testing,
      hasMistakeOnCurrent: false,
      isAllFinished: false,
      error: null,
      isNetworkError: false,
    );

    await _prepareCurrentCardOptions();
    return true;
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
      state = state.copyWith(currentPhase: ReviewCardPhase.grading);
    } else {
      if (!state.hasMistakeOnCurrent) {
        state = state.copyWith(hasMistakeOnCurrent: true);
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
    final currentItem = state.currentItem;
    if (currentItem == null) {
      return;
    }

    final items = List<WordReviewItem>.from(state.items);
    final answeredResults = List<WordReviewAnsweredResult>.from(
      state.answeredResults,
    );
    if (state.hasMistakeOnCurrent) {
      items.add(currentItem);
      answeredResults.add(
        WordReviewAnsweredResult(
          wordId: currentItem.studyWord.wordId,
          bookId: currentItem.studyWord.bookId,
          rating: ReviewRating.again,
        ),
      );
    } else {
      final elapsed = state.cardStartTime != null
          ? DateTime.now().difference(state.cardStartTime!).inMilliseconds /
                1000.0
          : 5.0;
      answeredResults.add(
        WordReviewAnsweredResult(
          wordId: currentItem.studyWord.wordId,
          bookId: currentItem.studyWord.bookId,
          rating: _ratingFromElapsed(elapsed),
        ),
      );
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= items.length) {
      state = state.copyWith(
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
        isAllFinished: true,
        items: items,
        answeredResults: answeredResults,
        currentIndex: nextIndex,
        currentOptions: const [],
        cardStartTime: null,
        error: null,
        isNetworkError: false,
      );
      await _persistCurrentSession();
      await _completeCurrentSession();
    } else {
      state = state.copyWith(
        items: items,
        answeredResults: answeredResults,
        currentIndex: nextIndex,
        currentPhase: ReviewCardPhase.testing,
        hasMistakeOnCurrent: false,
        error: null,
        isNetworkError: false,
      );
      await _persistCurrentSession();
      await _prepareCurrentCardOptions();
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
  }

  Future<void> _persistCurrentSession() async {
    final sessionId = state.sessionId;
    final localSessionId = state.localSessionId;
    final createdAt = state.sessionCreatedAt;
    final userId = _resolveLocalUserId();
    if (sessionId == null ||
        localSessionId == null ||
        createdAt == null ||
        userId == null) {
      return;
    }

    final session = LearningSession.wordReview(
      id: localSessionId,
      userId: userId,
      serverSessionId: sessionId,
      dataPayload: encodeWordReviewSessionPayload(
        initialItems: state.initialItems,
        dynamicQueue: state.items,
        answeredResults: state.answeredResults,
        currentIndex: state.currentIndex,
      ),
      createdAt: createdAt,
    );
    await _sessionRepo.updateSession(session);
  }

  Future<bool> _completeCurrentSession({bool autoRestartOnStale = true}) async {
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return false;
    }

    try {
      await _reviewSessionRemoteCommand.completeWordSession(
        sessionId: sessionId,
        results: state.answeredResults,
      );
      await _deleteLocalSession();
      _homeSummaryInvalidation.markStale();
      state = state.copyWith(
        localSessionId: null,
        sessionId: null,
        sessionCreatedAt: null,
        error: null,
        isNetworkError: false,
      );
      return true;
    } catch (error) {
      if (_isStaleSessionError(error)) {
        await _deleteLocalSession();
        state = state.copyWith(
          localSessionId: null,
          sessionId: null,
          sessionCreatedAt: null,
          error: null,
          isNetworkError: false,
        );
        if (autoRestartOnStale) {
          await loadReview();
        }
        return false;
      }

      logger.error(
        'Complete word review session failed',
        error,
        StackTrace.current,
      );
      final isNetworkError = _isNetworkError(error);
      state = state.copyWith(
        isLoading: false,
        error: isNetworkError ? null : error.toString(),
        isNetworkError: isNetworkError,
      );
      return false;
    }
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

  Future<void> _deleteLocalSession() async {
    final localSessionId = state.localSessionId;
    if (localSessionId == null) {
      return;
    }
    await _sessionRepo.deleteSession(localSessionId);
  }

  bool _isSessionExpired(DateTime createdAt) {
    return DateTime.now().difference(createdAt) > _sessionTtl;
  }

  int? _resolveLocalUserId() {
    if (state.items.isNotEmpty) {
      return state.items.first.studyWord.userId;
    }
    if (state.initialItems.isNotEmpty) {
      return state.initialItems.first.studyWord.userId;
    }
    return null;
  }

  bool _isStaleSessionError(Object error) {
    return error is DioException && error.response?.statusCode == 409;
  }

  bool _isNetworkError(Object error) {
    return error is NetworkException ||
        (error is DioException && error.type != DioExceptionType.badResponse);
  }
}
