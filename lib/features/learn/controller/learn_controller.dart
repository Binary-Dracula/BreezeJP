import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/word_repository_provider.dart';
import '../../../data/repositories/study_word_repository_provider.dart';
import '../../../data/repositories/study_log_repository_provider.dart';
import '../../../data/repositories/daily_stat_repository_provider.dart';
import '../state/learn_state.dart';

/// 学习页控制器
/// 管理学习页的状态和业务逻辑
class LearnController extends Notifier<LearnState> {
  /// 学习会话开始时间
  DateTime? _sessionStartTime;

  /// 当前用户 ID（暂时硬编码为 1）
  static const int _userId = 1;

  @override
  LearnState build() {
    return const LearnState();
  }

  /// 初始化学习（传入选中的单词 ID）
  Future<void> initWithWord(int wordId) async {
    _sessionStartTime = DateTime.now();
    state = state.copyWith(isLoading: true, error: null);

    try {
      final wordRepository = ref.read(wordRepositoryProvider);

      // 1. 获取选中单词的详情
      final selectedWord = await wordRepository.getWordDetail(wordId);
      if (selectedWord == null) {
        state = state.copyWith(isLoading: false, error: '单词不存在');
        return;
      }

      // 2. 加载关联词
      final relatedWords = await wordRepository.getRelatedWords(wordId);
      final relatedDetails = <dynamic>[];
      for (final related in relatedWords) {
        final detail = await wordRepository.getWordDetail(related.word.id);
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

      logger.learnSessionStart(userId: _userId);
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
      final wordRepository = ref.read(wordRepositoryProvider);
      final relatedWords = await wordRepository.getRelatedWords(wordId);

      if (relatedWords.isEmpty) {
        // 断链：没有更多关联词
        state = state.copyWith(isLoadingMore: false, pathEnded: true);
        logger.info('路径结束: 单词 $wordId 没有更多关联词');
        return;
      }

      // 加载关联词详情
      final relatedDetails = <dynamic>[];
      for (final related in relatedWords) {
        final detail = await wordRepository.getWordDetail(related.word.id);
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
      final studyWordRepository = ref.read(studyWordRepositoryProvider);
      final studyLogRepository = ref.read(studyLogRepositoryProvider);

      // 更新 learnedWordIds
      final newLearnedWordIds = {...state.learnedWordIds, wordId};
      state = state.copyWith(learnedWordIds: newLearnedWordIds);

      // 更新数据库
      await studyWordRepository.markAsLearned(userId: _userId, wordId: wordId);

      // 插入学习日志
      await studyLogRepository.logFirstLearn(
        userId: _userId,
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
      final dailyStatRepository = ref.read(dailyStatRepositoryProvider);
      final durationMs = DateTime.now()
          .difference(_sessionStartTime!)
          .inMilliseconds;

      await dailyStatRepository.updateDailyStats(
        userId: _userId,
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
    state = const LearnState();
  }
}

/// LearnController Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new,
);
