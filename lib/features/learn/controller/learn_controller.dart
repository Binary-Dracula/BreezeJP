import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/learning_status.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/word_command.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/models/user.dart';
import '../../../data/models/word_detail.dart';
import '../../../data/queries/study_word_query.dart';
import '../../../data/queries/word_read_queries.dart';
import '../../../data/queries/vocab_remote_query_provider.dart';
import '../../../data/repositories/word_content_repository_provider.dart';
import '../../../data/commands/session/session_scope.dart';
import '../../../data/commands/session/study_session_handle.dart';
import '../../../data/commands/study_session_command_provider.dart';
import '../state/learn_state.dart';

/// 学习页控制器（2.0 — 书籍顺序学习，无 island 逻辑）
class LearnController extends Notifier<LearnState> {
  DateTime? _sessionStartTime;
  int? _userId;
  String? _currentBookId;
  StudySessionHandle? _session;

  /// 本次 Session 内已 ensureSeen 的 wordId 集合
  final Set<String> _seenEnsuredWordIds = {};

  /// 本次 Session 内每个 wordId 的 getWordDetail 调用次数
  final Map<String, int> _wordDetailLoadCount = {};

  @override
  LearnState build() {
    return const LearnState();
  }

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyWordQuery get _studyWordQuery => ref.read(studyWordQueryProvider);
  WordCommand get _wordCommand => ref.read(wordCommandProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  /// 拉取下一批单词：API 优先，失败则 fallback 到本地缓存
  Future<List<WordDetail>> _fetchNextBatch(String bookId, int userId) async {
    final wordQueries = ref.read(wordReadQueriesProvider);
    final batchSize = ref.read(learnBatchSizeProvider);

    // 1. 本地 cursor（基于已学习的最大 book_sort_order）
    final cursor = await wordQueries.getMaxLearnedSortOrder(bookId, userId);

    // 2. 尝试 API 拉取
    try {
      final remote = ref.read(vocabRemoteQueryProvider);
      final response = await remote.fetchNextWords(
        bookId: bookId,
        afterSort: cursor,
        limit: batchSize,
      );

      if (response.words.isNotEmpty) {
        // 3. 保存到本地 DB（words + word_details + word_examples + lesson_word_map）
        final repo = ref.read(wordContentRepositoryProvider);
        await repo.saveBookWordMappings(bookId, response.words);

        logger.info(
          '从 API 拉取单词: bookId=$bookId, cursor=$cursor, '
          'count=${response.words.length}, hasMore=${response.hasMore}',
        );

        return response.words.map((w) => w.detail).toList();
      }
    } catch (e) {
      logger.warning('API 拉取失败，尝试本地缓存: $e');
    }

    // 4. Fallback: 从本地缓存取
    return wordQueries.getNextWordsInBook(
      bookId,
      afterSort: cursor,
      limit: batchSize,
      userId: userId,
    );
  }

  /// 开始书籍学习（从当前进度之后按 book_sort_order 取词）
  ///
  /// 优先走 API 拉取，保存到本地后学习；网络失败时 fallback 到本地缓存。
  Future<void> startBookLearning(String bookId) async {
    final userId = await _ensureUserId();
    await _session?.flush();
    _session = ref
        .read(studySessionCommandProvider)
        .createSession(userId: userId, scope: SessionScope.learn);
    _sessionStartTime = DateTime.now();
    _currentBookId = bookId;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final words = await _fetchNextBatch(bookId, userId);

      if (words.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          pathEnded: true,
          currentBookId: bookId,
        );
        logger.info('书籍学习: 没有更多新词 bookId=$bookId');
        return;
      }

      // 应用用户状态
      final queueWithState = await _applyUserStates(userId, words);

      state = state.copyWith(
        studyQueue: queueWithState,
        currentIndex: 0,
        learnedWordIds: {},
        isLoading: false,
        pathEnded: false,
        currentBookId: bookId,
      );
      await _onWordsLoaded(queueWithState);

      logger.learnSessionStart(userId: userId);
      logger.info('书籍学习初始化: bookId=$bookId, 加载=${queueWithState.length}个词');
    } catch (e, stackTrace) {
      logger.error('学习初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 页面切换回调
  Future<void> onPageChanged(int newIndex) async {
    state = state.copyWith(currentIndex: newIndex);

    // 首次看到单词时确保 seen 记录
    await _ensureSeenForCurrentWord();

    HapticFeedback.lightImpact();

    // 接近队列末尾时自动加载更多
    if (newIndex >= state.studyQueue.length - 3 &&
        !state.pathEnded &&
        !state.isLoadingMore) {
      await loadMoreWords();
    }

    logger.learnWordView(
      wordId: state.currentWordDetail?.word.id ?? '',
      position: newIndex + 1,
      total: state.studyQueue.length,
    );
  }

  /// 加载更多单词（按 book_sort_order 接续取下一批）
  Future<void> loadMoreWords() async {
    if (_currentBookId == null) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final userId = await _ensureUserId();
      final words = await _fetchNextBatch(_currentBookId!, userId);

      if (words.isEmpty) {
        state = state.copyWith(isLoadingMore: false, pathEnded: true);
        logger.info('书籍学习: 没有更多新词');
        return;
      }

      final queueWithState = await _applyUserStates(userId, words);

      state = state.copyWith(
        studyQueue: [...state.studyQueue, ...queueWithState],
        isLoadingMore: false,
      );

      logger.info('加载更多单词: ${queueWithState.length}个');
    } catch (e, stackTrace) {
      logger.error('加载更多单词失败', e, stackTrace);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 标记单词为已学习
  Future<void> markWordAsLearned(String wordId) async {
    if (state.learnedWordIds.contains(wordId)) return;

    try {
      final userId = await _ensureUserId();
      final session =
          _session ??
          ref
              .read(studySessionCommandProvider)
              .createSession(userId: userId, scope: SessionScope.learn);
      _session ??= session;

      final newLearnedWordIds = {...state.learnedWordIds, wordId};
      state = state.copyWith(learnedWordIds: newLearnedWordIds);

      await session.submitFirstLearn(wordId: wordId);

      logger.info('标记单词为已学习: wordId=$wordId');
    } catch (e, stackTrace) {
      logger.error('标记单词失败', e, stackTrace);
    }
  }

  Future<void> endSession() async {
    try {
      await _session?.flush();
    } catch (e, stackTrace) {
      logger.error('学习 Session flush 失败', e, stackTrace);
    } finally {
      _logWordDetailLoadSummary();
      _session = null;
      _sessionStartTime = null;
    }
  }

  /// seen -> learning（加入复习）
  Future<void> addCurrentWordToReview() async {
    final word = state.currentWordDetail;
    if (word == null) return;

    logger.info('[WordUI] action=add_to_review wordId=${word.word.id}');
    final user = await _getActiveUser();
    await _wordCommand.addWordToReview(user.id, word.word.id);
    await _refreshCurrentWordState(word.word.id);
  }

  /// seen -> learning -> mastered（一键掌握）
  Future<void> quickMasterCurrentWord() async {
    final word = state.currentWordDetail;
    if (word == null) return;

    logger.info('[WordUI] action=quick_master wordId=${word.word.id}');
    final user = await _getActiveUser();
    await _wordCommand.markWordAsMastered(user.id, word.word.id);
    await _refreshCurrentWordState(word.word.id);
  }

  /// learning -> mastered
  Future<void> markCurrentWordAsMastered() async {
    final word = state.currentWordDetail;
    if (word == null) return;

    logger.info('[WordUI] action=mark_mastered wordId=${word.word.id}');
    final user = await _getActiveUser();
    await _wordCommand.markWordAsMastered(user.id, word.word.id);
    await _refreshCurrentWordState(word.word.id);
  }

  /// mastered -> seen（恢复学习）
  Future<void> onRestoreLearningTapped(String wordId) async {
    logger.info('[WordUI] action=restore_to_seen wordId=$wordId');
    final user = await _getActiveUser();
    await _wordCommand.restoreToSeen(userId: user.id, wordId: wordId);
    await _refreshCurrentWordState(wordId);
  }

  /// toggle ignored（忽略 ↔ seen）
  Future<void> toggleCurrentWordIgnored() async {
    final word = state.currentWordDetail;
    if (word == null) return;

    logger.info('[WordUI] action=toggle_ignored wordId=${word.word.id}');
    final user = await _getActiveUser();
    await _wordCommand.toggleWordIgnored(user.id, word.word.id);
    await _refreshCurrentWordState(word.word.id);
  }

  /// 重置状态
  void reset() {
    _sessionStartTime = null;
    _userId = null;
    _currentBookId = null;
    _session = null;
    state = const LearnState();
  }

  Future<void> _refreshCurrentWordState(String wordId) async {
    final user = await _getActiveUser();
    final updated = await _studyWordQuery.getStudyWord(user.id, wordId);
    if (updated == null) return;

    final newQueue = state.studyQueue.map((item) {
      if (item.word.id != wordId) return item;
      return item.copyWith(userState: updated.userState);
    }).toList();

    state = state.copyWith(studyQueue: newQueue);
  }

  Future<void> _ensureSeenForCurrentWord() async {
    final word = state.currentWordDetail;
    if (word == null) return;

    final wordId = word.word.id;

    if (_seenEnsuredWordIds.contains(wordId)) return;

    if (word.userState != LearningStatus.seen) {
      _seenEnsuredWordIds.add(wordId);
      return;
    }

    final user = await _getActiveUser();
    await _wordCommand.ensureWordSeen(user.id, wordId);
    logger.debug(
      '[WordUI] wordId=$wordId ensure_seen triggered by page_changed',
    );

    _seenEnsuredWordIds.add(wordId);
  }

  Future<void> _onWordsLoaded(List<WordDetail> words) async {
    if (words.isEmpty) return;

    final user = await _getActiveUser();
    final firstWordId = words.first.word.id;
    await _wordCommand.ensureWordSeen(user.id, firstWordId);
  }

  void _logWordDetailLoadSummary() {
    _wordDetailLoadCount.forEach((wordId, count) {
      if (count > 1) {
        logger.debug(
          '[WordDetailLoadSummary] wordId=$wordId loaded $count times in one session',
        );
      } else {
        logger.debug('[WordDetailLoadSummary] wordId=$wordId loaded once');
      }
    });
  }

  Future<List<WordDetail>> _applyUserStates(
    int userId,
    List<WordDetail> details,
  ) async {
    final updatedDetails = <WordDetail>[];
    for (final detail in details) {
      final studyWord = await _studyWordQuery.getStudyWord(
        userId,
        detail.word.id,
      );
      final userState = studyWord?.userState ?? LearningStatus.seen;
      updatedDetails.add(detail.copyWith(userState: userState));
    }
    return updatedDetails;
  }
}

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
