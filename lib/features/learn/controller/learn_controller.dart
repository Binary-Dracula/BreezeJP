import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/models/learning_session.dart';
import '../../../data/models/user.dart';
import '../../../data/models/word_detail.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/vocab_remote_query.dart';
import '../../../data/queries/vocab_remote_query_provider.dart';
import '../../../data/repositories/learning_session_repository.dart';
import '../../../data/repositories/learning_session_repository_provider.dart';
import '../state/learn_state.dart';

class LearnController extends Notifier<LearnState> {
  static const _sessionTtl = Duration(days: 7);

  int? _userId;

  @override
  LearnState build() => const LearnState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  VocabRemoteQuery get _remote => ref.read(vocabRemoteQueryProvider);
  LearningSessionRepository get _sessionRepo =>
      ref.read(learningSessionRepositoryProvider);
  int get _batchSize => ref.read(learnBatchSizeProvider);
  int get _firstReviewIntervalMinutes => ref.read(firstReviewIntervalProvider);

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

      // 2. 无活跃会话 → 拉取新批次
      await _startNewBatch(bookId, userId);
    } catch (e, stackTrace) {
      logger.error('学习初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _resumeSession(LearningSession session, int userId) async {
    if (_isSessionExpired(session.createdAt)) {
      await _sessionRepo.deleteSession(session.id);
      await _startNewBatch(session.bookId ?? state.bookId ?? '', userId);
      return;
    }

    final sessionBookId = session.bookId ?? state.bookId;
    if (sessionBookId == null || sessionBookId.isEmpty) {
      await _sessionRepo.deleteSession(session.id);
      state = state.copyWith(isLoading: false, error: '学习会话缺少 bookId');
      return;
    }

    final wordsPayload = session.wordsPayload;
    if (wordsPayload == null || wordsPayload.isEmpty) {
      await _sessionRepo.deleteSession(session.id);
      await _startNewBatch(sessionBookId, userId);
      return;
    }

    final entries = decodeSessionWords(wordsPayload);
    final details = entries.map((entry) => entry.detail).toList();
    final restoredWordStates = _decodePersistedWordStates(session.dataPayload);

    if (session.currentIndex >= details.length &&
        session.serverSessionId != null) {
      state = state.copyWith(
        words: details,
        currentIndex: details.isEmpty ? 0 : details.length - 1,
        wordStates: restoredWordStates,
        isBatchComplete: true,
        isBookComplete: false,
        isResumed: true,
        isLoading: false,
        totalWordsInBook: state.totalWordsInBook,
        wordSortOrders: entries.map((e) => e.bookSortOrder).toList(),
      );
      await _completePersistedBatch(session, details, restoredWordStates);
      return;
    }

    state = state.copyWith(
      words: details,
      currentIndex: session.currentIndex,
      wordStates: restoredWordStates,
      isBatchComplete: false,
      isBookComplete: false,
      isResumed: true,
      isLoading: false,
      totalWordsInBook: state.totalWordsInBook,
      wordSortOrders: entries.map((e) => e.bookSortOrder).toList(),
    );

    logger.info(
      '[LearnCtrl] 恢复会话 bookId=$sessionBookId index=${session.currentIndex}',
    );
  }

  Future<void> _startNewBatch(String bookId, int userId) async {
    try {
      final response = await _remote.createLearnSession(
        bookId: bookId,
        limit: _batchSize,
      );

      final entries = response.words;

      if (entries.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          words: const [],
          isBookComplete: true,
          isBatchComplete: false,
          totalWordsInBook: response.totalWords,
          wordStates: const {},
          wordSortOrders: const [],
        );
        logger.info('[LearnCtrl] 书籍学习完毕 bookId=$bookId');
        return;
      }

      final remoteSessionId = response.sessionId;
      if (remoteSessionId == null || remoteSessionId.isEmpty) {
        throw StateError('学习会话缺少远端 session_id');
      }

      final batchEndSort = response.batchEndSort;
      final details = entries.map((entry) => entry.detail).toList();
      final wordsPayload = encodeSessionWords(response.rawWordsJson);

      // 创建新会话
      final sessionId = await _sessionRepo.createSession(
        LearningSession.wordLearn(
          userId: userId,
          serverSessionId: remoteSessionId,
          bookId: bookId,
          wordsPayload: wordsPayload,
          currentIndex: 0,
          batchStartSort: response.batchStartSort,
          batchEndSort: batchEndSort,
          status: 'active',
        ),
      );

      state = state.copyWith(
        words: details,
        currentIndex: 0,
        wordStates: const {},
        isBatchComplete: false,
        isBookComplete: false,
        isResumed: response.resumed,
        isLoading: false,
        totalWordsInBook: response.totalWords,
        wordSortOrders: entries.map((e) => e.bookSortOrder).toList(),
      );

      logger.info(
        '[LearnCtrl] 新批次 bookId=$bookId nextCursor=$batchEndSort count=${details.length} sessionId=$sessionId',
      );
    } on DioException catch (error, stackTrace) {
      if (_isBookUnavailableError(error)) {
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

      logger.error('云端学习批次拉取失败', error, stackTrace);
      rethrow;
    }
  }

  /// 用户手动标记忽略
  Future<void> markCurrentIgnored() async {
    final idx = state.currentIndex;
    final word = idx < state.words.length ? state.words[idx] : null;
    if (word == null) return;

    final newStates = Map<int, LearningStatus>.from(state.wordStates);
    newStates[idx] = LearningStatus.ignored;
    state = state.copyWith(wordStates: newStates);
    await _persistSessionSnapshot(currentIndex: idx, wordStates: newStates);

    await _advanceAfterDecision();
  }

  /// 用户手动标记已掌握
  Future<void> markCurrentMastered() async {
    final idx = state.currentIndex;
    final word = idx < state.words.length ? state.words[idx] : null;
    if (word == null) return;

    final newStates = Map<int, LearningStatus>.from(state.wordStates);
    newStates[idx] = LearningStatus.mastered;
    state = state.copyWith(wordStates: newStates);
    await _persistSessionSnapshot(currentIndex: idx, wordStates: newStates);

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

    await _persistSessionSnapshot(
      currentIndex: nextIndex,
      wordStates: state.wordStates,
    );
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

  Future<void> _persistSessionSnapshot({
    required int currentIndex,
    required Map<int, LearningStatus> wordStates,
  }) async {
    final userId = _userId;
    final bookId = state.bookId;
    if (userId == null || bookId == null) {
      return;
    }

    final session = await _sessionRepo.getActiveSession(userId, bookId);
    if (session == null) return;

    final payload = Map<String, dynamic>.from(session.decodedDataPayload);
    payload['current_index'] = currentIndex;
    payload['word_states'] = {
      for (final entry in wordStates.entries)
        entry.key.toString(): entry.value.value,
    };
    await _sessionRepo.updateSession(
      session.copyWith(dataPayload: jsonEncode(payload)),
    );
  }

  Future<void> _completeBatch() async {
    final userId = await _ensureUserId();
    final bookId = state.bookId;
    if (bookId == null) return;

    // 取得当前活跃会话
    final session = await _sessionRepo.getActiveSession(userId, bookId);
    if (session == null || session.serverSessionId == null) {
      state = state.copyWith(isLoading: false, error: '学习会话不存在，无法完成当前批次');
      return;
    }

    await _persistSessionSnapshot(
      currentIndex: state.words.length,
      wordStates: state.wordStates,
    );

    try {
      await _remote.completeLearnSession(
        sessionId: session.serverSessionId!,
        wordStates: _buildFinalWordStates(),
        firstReviewIntervalMinutes: _firstReviewIntervalMinutes,
      );
      await _sessionRepo.deleteSession(session.id);
      state = state.copyWith(
        isBatchComplete: true,
        currentIndex: state.words.length,
      );
      logger.info(
        '[LearnCtrl] 批次完成 bookId=$bookId cursor=${session.batchEndSort}',
      );
    } on DioException catch (error, stackTrace) {
      if (_isStaleSessionError(error)) {
        await _sessionRepo.deleteSession(session.id);
        await _startNewBatch(bookId, userId);
        return;
      }

      logger.error('学习批次完成失败', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isBatchComplete: true,
        currentIndex: state.words.length,
        error: null,
      );
    }
  }

  Future<void> _completePersistedBatch(
    LearningSession session,
    List<WordDetail> details,
    Map<int, LearningStatus> wordStates,
  ) async {
    final serverSessionId = session.serverSessionId;
    if (serverSessionId == null || serverSessionId.isEmpty) {
      await _sessionRepo.deleteSession(session.id);
      final userId = await _ensureUserId();
      await _startNewBatch(session.bookId!, userId);
      return;
    }

    try {
      await _remote.completeLearnSession(
        sessionId: serverSessionId,
        wordStates: _buildFinalWordStates(
          words: details,
          wordStates: wordStates,
        ),
        firstReviewIntervalMinutes: _firstReviewIntervalMinutes,
      );
      await _sessionRepo.deleteSession(session.id);
      state = state.copyWith(
        words: details,
        currentIndex: details.length,
        wordStates: wordStates,
        isBatchComplete: true,
        isBookComplete: false,
        isResumed: true,
        isLoading: false,
        error: null,
      );
    } on DioException catch (error, stackTrace) {
      if (_isStaleSessionError(error)) {
        await _sessionRepo.deleteSession(session.id);
        final userId = await _ensureUserId();
        await _startNewBatch(session.bookId!, userId);
        return;
      }

      logger.error('恢复后的学习批次完成失败', error, stackTrace);
      state = state.copyWith(
        words: details,
        currentIndex: details.length,
        wordStates: wordStates,
        isBatchComplete: true,
        isBookComplete: false,
        isResumed: true,
        isLoading: false,
        error: null,
      );
    }
  }

  Map<int, LearningStatus> _decodePersistedWordStates(String dataPayload) {
    final decoded = jsonDecode(dataPayload) as Map<String, dynamic>;
    final rawStates = decoded['word_states'];
    if (rawStates is! Map) {
      return const <int, LearningStatus>{};
    }

    final restored = <int, LearningStatus>{};
    for (final entry in rawStates.entries) {
      final index = int.tryParse(entry.key.toString());
      if (index == null) {
        continue;
      }
      final rawValue = switch (entry.value) {
        int number => number,
        String text => int.tryParse(text) ?? LearningStatus.learning.value,
        _ => LearningStatus.learning.value,
      };
      restored[index] = LearningStatus.fromValue(rawValue);
    }
    return restored;
  }

  List<LearnWordStateResult> _buildFinalWordStates({
    List<WordDetail>? words,
    Map<int, LearningStatus>? wordStates,
  }) {
    final resolvedWords = words ?? state.words;
    final resolvedWordStates = wordStates ?? state.wordStates;
    return List<LearnWordStateResult>.generate(
      resolvedWords.length,
      (index) => LearnWordStateResult(
        wordId: resolvedWords[index].word.id,
        userState: resolvedWordStates[index] ?? LearningStatus.learning,
      ),
      growable: false,
    );
  }

  bool _isSessionExpired(DateTime createdAt) {
    return DateTime.now().difference(createdAt) > _sessionTtl;
  }

  bool _isBookUnavailableError(DioException error) {
    return error.response?.statusCode == 409 &&
        ((error.response?.data as Map?)?['error'] as Map?)?['code'] ==
            'BOOK_UNAVAILABLE';
  }

  bool _isStaleSessionError(DioException error) {
    return error.response?.statusCode == 409 &&
        ((error.response?.data as Map?)?['error'] as Map?)?['code'] ==
            'STALE_SESSION';
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
