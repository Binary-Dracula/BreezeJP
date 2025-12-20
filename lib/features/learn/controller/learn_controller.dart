import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/active_user_provider.dart';
import '../../../data/queries/word_read_queries.dart';
import '../../../data/commands/study_word_command.dart';
import '../state/learn_state.dart';

/// 学习页控制器
/// 管理学习页的状态和业务逻辑
class LearnController extends Notifier<LearnState> {
  /// 学习会话开始时间
  DateTime? _sessionStartTime;

  /// 当前用户 ID（从 app_state 表获取）
  int? _userId;

  @override
  LearnState build() {
    return const LearnState();
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await ref.read(activeUserProvider.future)).id;
    return _userId!;
  }

  /// 初始化学习（传入选中的单词 ID）
  Future<void> initWithWord(int wordId) async {
    final userId = await _ensureUserId();
    _sessionStartTime = DateTime.now();
    state = state.copyWith(isLoading: true, error: null);

    try {
      final wordQueries = ref.read(wordReadQueriesProvider);

      // 1. 获取选中单词的详情
      final selectedWord = await wordQueries.getWordDetail(wordId);
      if (selectedWord == null) {
        state = state.copyWith(isLoading: false, error: '单词不存在');
        return;
      }

      // 2. 加载关联词
      final relatedWords = await wordQueries.getRelatedWords(
        userId: userId,
        wordId: wordId,
      );
      final relatedDetails = <dynamic>[];
      for (final related in relatedWords) {
        final detail = await wordQueries.getWordDetail(related.word.id);
        if (detail != null) {
          relatedDetails.add(detail);
        }
      }

      // 3. 初始化学习队列
      state = state.copyWith(
        studyQueue: [selectedWord, ...relatedDetails.cast()],
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
      final relatedDetails = <dynamic>[];
      for (final related in relatedWords) {
        final detail = await wordQueries.getWordDetail(related.word.id);
        if (detail != null) {
          relatedDetails.add(detail);
        }
      }

      // 追加到学习队列
      state = state.copyWith(
        studyQueue: [...state.studyQueue, ...relatedDetails.cast()],
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
      final studyWordCommand = ref.read(studyWordCommandProvider);

      // 更新 learnedWordIds
      final newLearnedWordIds = {...state.learnedWordIds, wordId};
      state = state.copyWith(learnedWordIds: newLearnedWordIds);

      // 更新数据库
      await studyWordCommand.markAsLearned(userId: userId, wordId: wordId);

      // 插入学习日志
      await studyWordCommand.logFirstLearn(
        userId: userId,
        wordId: wordId,
        durationMs: 0,
      );

      logger.info('标记单词为已学习: wordId=$wordId');
    } catch (e, stackTrace) {
      logger.error('标记单词失败', e, stackTrace);
    }
  }

  /// 更新每日统计
  Future<void> updateDailyStats() async {
    if (_sessionStartTime == null) return;

    try {
      final userId = await _ensureUserId();
      final studyWordCommand = ref.read(studyWordCommandProvider);
      final durationMs = DateTime.now()
          .difference(_sessionStartTime!)
          .inMilliseconds;

      await studyWordCommand.updateDailyStats(
        userId: userId,
        learnedCount: state.learnedCount,
        durationMs: durationMs,
      );

      logger.learnSessionEnd(
        durationMs: durationMs,
        learnedCount: state.learnedCount,
        reviewedCount: 0,
      );
    } catch (e, stackTrace) {
      logger.error('更新每日统计失败', e, stackTrace);
    }
  }

  /// 重置状态
  void reset() {
    _sessionStartTime = null;
    _userId = null;
    state = const LearnState();
  }
}

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
