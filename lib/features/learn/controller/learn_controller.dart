import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/learning_status.dart';
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
import '../../../data/commands/session/session_scope.dart';
import '../../../data/commands/session/study_session_handle.dart';
import '../../../data/commands/study_session_command_provider.dart';
import '../state/learn_state.dart';

/// 学习页控制器
/// 管理学习页的状态和业务逻辑
class LearnController extends Notifier<LearnState> {
  /// 上一次学习动作时间
  DateTime? _sessionStartTime;

  /// 当前用户 ID（从 app_state 表获取）
  int? _userId;
  StudySessionHandle? _session;

  /// 本次 Learn Session 内，已经触发过 ensureSeen 的 wordId 集合
  final Set<int> _seenEnsuredWordIds = {};

  /// 本次 Learn Session 内，每个 wordId 的 getWordDetail 调用次数
  final Map<int, int> _wordDetailLoadCount = {};

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

  /// 初始化学习（传入选中的单词 ID）
  Future<void> initWithWord(int wordId) async {
    final userId = await _ensureUserId();
    await _session?.flush();
    _session =
        ref.read(studySessionCommandProvider).createSession(
              userId: userId,
              scope: SessionScope.learn,
            );
    _sessionStartTime = DateTime.now();
    state = state.copyWith(isLoading: true, error: null);

    try {
      final wordQueries = ref.read(wordReadQueriesProvider);

      // 1. 获取选中单词的详情
      final selectedWord = await _loadWordDetailWithLog(wordId);
      if (selectedWord == null) {
        state = state.copyWith(isLoading: false, error: '单词不存在');
        return;
      }

      // 2. 加载关联词
      final relatedWords = await wordQueries.getRelatedWords(
        userId: userId,
        wordId: wordId,
      );
      final relatedDetails = <WordDetail>[];
      for (final related in relatedWords) {
        final detail = await _loadWordDetailWithLog(related.word.id);
        if (detail != null) {
          relatedDetails.add(detail);
        }
      }

      // 3. 初始化学习队列
      final queueWithState = await _applyUserStates(
        userId,
        [selectedWord, ...relatedDetails],
      );
      state = state.copyWith(
        studyQueue: queueWithState,
        currentIndex: 0,
        learnedWordIds: {},
        isLoading: false,
        pathEnded: relatedWords.isEmpty,
      );

      logger.learnSessionStart(userId: userId);
      logger.info(
        '学习初始化完成: 起始单词=${selectedWord.word.word}, 关联词=${relatedDetails.length}个',
      );
    } catch (e, stackTrace) {
      logger.error('学习初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 页面切换回调
  Future<void> onPageChanged(int newIndex) async {
    final oldIndex = state.currentIndex;

    // 向前滑动时标记上一个单词为已学习
    if (newIndex > oldIndex && oldIndex < state.studyQueue.length) {
      final previousWordId = state.studyQueue[oldIndex].word.id;
      if (!state.learnedWordIds.contains(previousWordId)) {
        await markWordAsLearned(previousWordId);
      }
    }

    // 更新当前索引
    state = state.copyWith(currentIndex: newIndex);

    // 首次看到单词时，确保 seen 记录存在
    await _ensureSeenForCurrentWord();

    // 触发触觉反馈
    HapticFeedback.lightImpact();

    // 检查是否到达队列末尾，触发加载更多
    if (state.isAtQueueEnd && !state.pathEnded && !state.isLoadingMore) {
      final currentWord = state.currentWordDetail;
      if (currentWord != null) {
        await loadRelatedWords(currentWord.word.id);
      }
    }

    logger.learnWordView(
      wordId: state.currentWordDetail?.word.id ?? 0,
      position: newIndex + 1,
      total: state.studyQueue.length,
    );
  }

  /// 加载关联词
  Future<void> loadRelatedWords(int wordId) async {
    state = state.copyWith(isLoadingMore: true);

    try {
      final userId = await _ensureUserId();
      final wordQueries = ref.read(wordReadQueriesProvider);
      final relatedWords = await wordQueries.getRelatedWords(
        userId: userId,
        wordId: wordId,
      );

      if (relatedWords.isEmpty) {
        // 断链：没有更多关联词
        state = state.copyWith(isLoadingMore: false, pathEnded: true);
        logger.info('路径结束: 单词 $wordId 没有更多关联词');
        return;
      }

      // 加载关联词详情
      final relatedDetails = <WordDetail>[];
      for (final related in relatedWords) {
        final detail = await _loadWordDetailWithLog(related.word.id);
        if (detail != null) {
          relatedDetails.add(detail);
        }
      }

      final updatedRelatedDetails = await _applyUserStates(
        userId,
        relatedDetails,
      );

      // 追加到学习队列
      state = state.copyWith(
        studyQueue: [...state.studyQueue, ...updatedRelatedDetails],
        isLoadingMore: false,
      );

      logger.info('加载关联词完成: ${relatedDetails.length}个新单词');
    } catch (e, stackTrace) {
      logger.error('加载关联词失败', e, stackTrace);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 标记单词为已学习
  Future<void> markWordAsLearned(int wordId) async {
    // 检查是否已在 learnedWordIds 中，避免重复标记
    if (state.learnedWordIds.contains(wordId)) {
      return;
    }

    try {
      final userId = await _ensureUserId();
      final session =
          _session ??
          ref.read(studySessionCommandProvider).createSession(
                userId: userId,
                scope: SessionScope.learn,
              );
      _session ??= session;
      final now = DateTime.now();
      final durationMs = _sessionStartTime == null
          ? 0
          : now.difference(_sessionStartTime!).inMilliseconds;
      _sessionStartTime = now;

      // 更新 learnedWordIds
      final newLearnedWordIds = {...state.learnedWordIds, wordId};
      state = state.copyWith(learnedWordIds: newLearnedWordIds);

      await session.submitFirstLearn(
        wordId: wordId,
        durationMs: durationMs,
      );

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
    _session = null;
    state = const LearnState();
  }

  Future<void> _refreshCurrentWordState(int wordId) async {
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

    // Session 级去重：同一个 word 只处理一次
    if (_seenEnsuredWordIds.contains(wordId)) {
      return;
    }

    // 仅当当前状态为 seen 才允许创建
    if (word.userState != LearningStatus.seen) {
      _seenEnsuredWordIds.add(wordId);
      return;
    }

    final user = await _getActiveUser();
    await _wordCommand.getOrCreateLearningState(user.id, wordId);
    logger.info(
      '[WordUI] wordId=$wordId ensure_seen triggered by page_changed',
    );

    // 标记该 word 在本 session 中已 ensure
    _seenEnsuredWordIds.add(wordId);
  }

  Future<WordDetail?> _loadWordDetailWithLog(int wordId) async {
    final count = (_wordDetailLoadCount[wordId] ?? 0) + 1;
    _wordDetailLoadCount[wordId] = count;

    logger.info(
      '[WordDetailLoad] session wordId=$wordId count=$count',
    );

    final wordQueries = ref.read(wordReadQueriesProvider);
    return wordQueries.getWordDetail(wordId);
  }

  void _logWordDetailLoadSummary() {
    _wordDetailLoadCount.forEach((wordId, count) {
      if (count > 1) {
        logger.warning(
          '[WordDetailLoadSummary] wordId=$wordId loaded $count times in one session',
        );
      } else {
        logger.info(
          '[WordDetailLoadSummary] wordId=$wordId loaded once',
        );
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
