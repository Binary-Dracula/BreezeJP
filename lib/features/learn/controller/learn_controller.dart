import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/book_progress_command.dart';
import '../../../data/commands/study_word_command.dart';
import '../../../data/models/learning_session.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/book_query.dart';
import '../../../data/queries/book_query_provider.dart';
import '../../../data/queries/vocab_remote_query.dart';
import '../../../data/queries/vocab_remote_query_provider.dart';
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
  BookQuery get _bookQuery => ref.read(bookQueryProvider);
  LearningSessionRepository get _sessionRepo =>
      ref.read(learningSessionRepositoryProvider);

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
    final wordsPayload = session.wordsPayload;
    if (wordsPayload == null || wordsPayload.isEmpty) {
      await _sessionRepo.deleteAllByBook(userId, session.bookId);
      await _startNewBatch(session.bookId, userId);
      return;
    }

    final entries = decodeSessionWords(wordsPayload);
    final details = entries.map((entry) => entry.detail).toList();

    state = state.copyWith(
      words: details,
      currentIndex: session.currentIndex,
      wordStates: const {},
      isBatchComplete: false,
      isBookComplete: false,
      isResumed: true,
      isLoading: false,
      totalWordsInBook: state.totalWordsInBook,
      wordSortOrders: entries.map((e) => e.bookSortOrder).toList(),
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

    final remote = ref.read(vocabRemoteQueryProvider);
    NextWordsResponse response;
    try {
      response = await remote.fetchUserNextWords(
        bookId: bookId,
        limit: batchSize,
      );
    } catch (e, stackTrace) {
      logger.warning('云端游标拉取失败，回退到本地游标: $bookId');
      logger.error('云端学习批次拉取失败', e, stackTrace);
      final progress = await ref
          .read(bookProgressRepositoryProvider)
          .getProgress(userId, bookId);
      final cursor = progress?.currentSortCursor ?? 0;
      response = await remote.fetchNextWords(
        bookId: bookId,
        afterSort: cursor,
        limit: batchSize,
      );
    }

    final entries = response.words;

    if (entries.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        words: const [],
        isBookComplete: true,
        isBatchComplete: false,
        totalWordsInBook: response.totalWords,
      );
      logger.info('[LearnCtrl] 书籍学习完毕 bookId=$bookId');
      return;
    }

    final wordIds = entries.map((e) => e.detail.word.id).toList();
    final batchEndSort = response.nextCursor;
    final details = entries.map((entry) => entry.detail).toList();
    final wordsPayload = encodeSessionWords(response.rawWordsJson);

    // 创建新会话
    final now = DateTime.now();
    final sessionId = await _sessionRepo.createSession(
      LearningSession(
        id: 0,
        userId: userId,
        bookId: bookId,
        wordIds: wordIds,
        wordsPayload: wordsPayload,
        currentIndex: 0,
        batchStartSort: entries.first.bookSortOrder - 1,
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
      totalWordsInBook: response.totalWords,
      wordSortOrders: entries.map((e) => e.bookSortOrder).toList(),
    );

    // 翻到即标记
    unawaited(_markCurrentViewed(0, userId, bookId));

    logger.info(
      '[LearnCtrl] 新批次 bookId=$bookId nextCursor=$batchEndSort count=${details.length} sessionId=$sessionId',
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

    // 每翻一张即推进游标，防止 app 关闭后游标丢失导致重复学习
    if (index < state.wordSortOrders.length) {
      final sortOrder = state.wordSortOrders[index];
      unawaited(
        _bookProgressCommand.refreshProgress(
          userId: userId,
          bookId: bookId,
          newCursor: sortOrder,
          totalWordsInBook: state.totalWordsInBook,
        ),
      );
    }
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

    await _bookProgressCommand.refreshProgress(
      userId: userId,
      bookId: bookId,
      newCursor: batchEndSort,
      totalWordsInBook: state.totalWordsInBook,
    );

    state = state.copyWith(isBatchComplete: true);
    logger.info('[LearnCtrl] 批次完成 bookId=$bookId cursor=$batchEndSort');
  }
}

String encodeSessionWords(List<Map<String, dynamic>> rawWordsJson) {
  return jsonEncode(rawWordsJson);
}

List<WordDetailWithSort> decodeSessionWords(String payload) {
  final parsed = jsonDecode(payload) as List<dynamic>;
  return parsed
      .map(
        (item) =>
            WordDetailWithSort.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
