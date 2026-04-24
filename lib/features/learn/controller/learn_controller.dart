import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/book_progress_command.dart';
import '../../../data/commands/study_word_command.dart';
import '../../../data/commands/word_introduction_command.dart';
import '../../../data/commands/word_introduction_command_provider.dart';
import '../../../data/models/learning_session.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/book_query.dart';
import '../../../data/queries/book_query_provider.dart';
import '../../../data/queries/vocab_remote_query_provider.dart';
import '../../../data/queries/word_read_queries.dart';
import '../../../data/repositories/book_progress_repository.dart';
import '../../../data/repositories/book_progress_repository_provider.dart';
import '../../../data/repositories/learning_session_repository.dart';
import '../../../data/repositories/learning_session_repository_provider.dart';
import '../state/learn_state.dart';

/// 学习页控制器（2.0 — 批次式学习，翻到即标记 learned）
class LearnController extends Notifier<LearnState> {
  int? _userId;

  @override
  LearnState build() => const LearnState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyWordCommand get _studyWordCommand => ref.read(studyWordCommandProvider);
  BookProgressCommand get _bookProgressCommand =>
      ref.read(bookProgressCommandProvider);
  WordIntroductionCommand get _wordIntroductionCommand =>
      ref.read(wordIntroductionCommandProvider);
  BookQuery get _bookQuery => ref.read(bookQueryProvider);
  WordReadQueries get _wordQueries => ref.read(wordReadQueriesProvider);
  LearningSessionRepository get _sessionRepo =>
      ref.read(learningSessionRepositoryProvider);
  BookProgressRepository get _progressRepo =>
      ref.read(bookProgressRepositoryProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  /// 开始/恢复学习某本书
  Future<void> startLearning(String bookId) async {
    state = state.copyWith(
      isLoading: true,
      bookId: bookId,
      error: null,
      isBookUnavailableForNextBatch: false,
    );

    try {
      final userId = await _ensureUserId();

      // 1. 检查是否有未完成的会话（断点恢复）
      final activeSession = await _sessionRepo.getActiveSession(userId, bookId);
      if (activeSession != null) {
        await _resumeSession(activeSession, userId);
        return;
      }

      final isAvailable = await _bookQuery.isBookAvailable(bookId);
      if (!isAvailable) {
        final selectedBookId = ref.read(selectedBookIdProvider);
        if (selectedBookId == bookId) {
          await ref.read(selectedBookIdProvider.notifier).setBookId(null);
        }
        state = state.copyWith(
          isLoading: false,
          words: const [],
          isBatchComplete: false,
          isBookComplete: false,
          isBookUnavailableForNextBatch: true,
        );
        return;
      }

      // 2. 无活跃会话 → 拉取新批次
      await _startNewBatch(bookId, userId);
    } catch (e, stackTrace) {
      logger.error('学习初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _resumeSession(LearningSession session, int userId) async {
    final details = await _wordQueries.getWordDetails(
      session.wordIds,
      userId: userId,
    );

    state = state.copyWith(
      words: details,
      currentIndex: session.currentIndex,
      wordStates: const {},
      isBatchComplete: false,
      isBookComplete: false,
      isResumed: true,
      isLoading: false,
    );

    // 把当前卡片标记为已学
    if (details.isNotEmpty) {
      unawaited(
        _markCurrentViewed(session.currentIndex, userId, session.bookId),
      );
    }

    logger.info(
      '[LearnCtrl] 恢复会话 bookId=${session.bookId} index=${session.currentIndex}',
    );
  }

  Future<void> _startNewBatch(String bookId, int userId) async {
    final batchSize = ref.read(learnBatchSizeProvider);
    final progress = await _progressRepo.getProgress(userId, bookId);
    final cursor = progress?.currentSortCursor ?? 0;

    // 拉取新词 ID（排除已学）
    var entries = await _wordQueries.getNextBatchWordIds(
      bookId,
      afterSortOrder: cursor,
      limit: batchSize,
      userId: userId,
    );

    if (entries.isEmpty) {
      // 尝试从 API 拉
      try {
        final remote = ref.read(vocabRemoteQueryProvider);
        final response = await remote.fetchNextWords(
          bookId: bookId,
          afterSort: cursor,
          limit: batchSize,
        );

        if (response.words.isNotEmpty) {
          await _wordIntroductionCommand.introduceFetchedWords(
            bookId: bookId,
            words: response.words,
          );
          entries = await _wordQueries.getNextBatchWordIds(
            bookId,
            afterSortOrder: cursor,
            limit: batchSize,
            userId: userId,
          );
        }
      } catch (e) {
        logger.warning('API 拉取失败: $e');
      }
    }

    if (entries.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        words: const [],
        isBookComplete: true,
        isBatchComplete: false,
      );
      logger.info('[LearnCtrl] 书籍学习完毕 bookId=$bookId');
      return;
    }

    final wordIds = entries.map((e) => e.wordId).toList();
    final batchEndSort = entries.last.bookSortOrder;
    final details = await _wordQueries.getWordDetails(wordIds, userId: userId);

    // 创建新会话
    final now = DateTime.now();
    final sessionId = await _sessionRepo.createSession(
      LearningSession(
        id: 0,
        userId: userId,
        bookId: bookId,
        wordIds: wordIds,
        currentIndex: 0,
        batchStartSort: cursor,
        batchEndSort: batchEndSort,
        startedAt: now,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    );

    state = state.copyWith(
      words: details,
      currentIndex: 0,
      wordStates: const {},
      isBatchComplete: false,
      isBookComplete: false,
      isResumed: false,
      isLoading: false,
    );

    // 翻到即标记
    unawaited(_markCurrentViewed(0, userId, bookId));

    logger.info(
      '[LearnCtrl] 新批次 bookId=$bookId cursor=$cursor count=${details.length} sessionId=$sessionId',
    );
  }

  /// 用户手动标记忽略
  Future<void> markCurrentIgnored() async {
    final idx = state.currentIndex;
    final word = idx < state.words.length ? state.words[idx] : null;
    if (word == null) return;
    final userId = await _ensureUserId();
    final bookId = state.bookId;
    if (bookId == null) return;

    await _studyWordCommand.markAsIgnored(
      userId: userId,
      wordId: word.word.id,
      bookId: bookId,
    );

    final newStates = Map<int, LearningStatus>.from(state.wordStates);
    newStates[idx] = LearningStatus.ignored;
    state = state.copyWith(wordStates: newStates);

    await _advanceAfterDecision();
  }

  /// 用户手动标记已掌握
  Future<void> markCurrentMastered() async {
    final idx = state.currentIndex;
    final word = idx < state.words.length ? state.words[idx] : null;
    if (word == null) return;
    final userId = await _ensureUserId();
    final bookId = state.bookId;
    if (bookId == null) return;

    await _studyWordCommand.markAsMastered(
      userId: userId,
      wordId: word.word.id,
      bookId: bookId,
    );

    final newStates = Map<int, LearningStatus>.from(state.wordStates);
    newStates[idx] = LearningStatus.mastered;
    state = state.copyWith(wordStates: newStates);

    await _advanceAfterDecision();
  }

  /// 前进到下一张卡片（若已在末尾则完成批次）
  Future<void> goToNext() async {
    if (state.isAtLastCard) {
      await _completeBatch();
      return;
    }

    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(
      currentIndex: nextIndex,
      slideDirection: SlideDirection.next,
    );

    final userId = await _ensureUserId();
    final bookId = state.bookId;
    if (bookId != null) {
      unawaited(_markCurrentViewed(nextIndex, userId, bookId));
      unawaited(_updateSessionIndex(nextIndex, userId, bookId));
    }
  }

  /// 返回上一张卡片
  void goToPrev() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      slideDirection: SlideDirection.prev,
    );
  }

  /// 继续学习下一批（批次完成页 "继续" 按钮）
  Future<void> continueNextBatch() async {
    final bookId = state.bookId;
    if (bookId == null) return;
    await startLearning(bookId);
  }

  void acknowledgeBookUnavailableForNextBatch() {
    if (!state.isBookUnavailableForNextBatch) return;
    state = state.copyWith(isBookUnavailableForNextBatch: false);
  }

  void reset() {
    _userId = null;
    state = const LearnState();
  }

  // ================ Internal ================

  Future<void> _advanceAfterDecision() async {
    await goToNext();
  }

  Future<void> _markCurrentViewed(int index, int userId, String bookId) async {
    if (index < 0 || index >= state.words.length) return;
    final wordId = state.words[index].word.id;
    await _studyWordCommand.markAsLearned(
      userId: userId,
      wordId: wordId,
      bookId: bookId,
    );
  }

  Future<void> _updateSessionIndex(int index, int userId, String bookId) async {
    final session = await _sessionRepo.getActiveSession(userId, bookId);
    if (session == null) return;
    await _sessionRepo.updateSession(session.copyWith(currentIndex: index));
  }

  Future<void> _completeBatch() async {
    final userId = await _ensureUserId();
    final bookId = state.bookId;
    if (bookId == null) return;

    // 最后一张也要标记
    unawaited(_markCurrentViewed(state.currentIndex, userId, bookId));

    // 取得当前活跃会话
    final session = await _sessionRepo.getActiveSession(userId, bookId);
    final batchEndSort = session?.batchEndSort ?? 0;

    if (session != null) {
      await _sessionRepo.updateSession(session.copyWith(status: 'completed'));
    }

    // 刷新进度（totalWords 从 lesson_word_map 统计，暂时传 0 让 command 重算）
    final totalWordCount = await _getTotalBookWords(bookId);
    await _bookProgressCommand.refreshProgress(
      userId: userId,
      bookId: bookId,
      newCursor: batchEndSort,
      totalWordsInBook: totalWordCount,
    );

    state = state.copyWith(isBatchComplete: true);
    logger.info('[LearnCtrl] 批次完成 bookId=$bookId cursor=$batchEndSort');
  }

  Future<int> _getTotalBookWords(String bookId) async {
    try {
      final rows = await _wordQueries.getTotalWordCountInBook(bookId);
      return rows;
    } catch (_) {
      return 0;
    }
  }
}

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
