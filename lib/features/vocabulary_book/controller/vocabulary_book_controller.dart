import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/word_command.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/vocabulary_book_query.dart';
import '../../../data/queries/vocabulary_book_query_provider.dart';
import '../state/vocabulary_book_state.dart';

/// 单词本页控制器 Provider
final vocabularyBookControllerProvider =
    NotifierProvider<VocabularyBookController, VocabularyBookState>(
      VocabularyBookController.new,
    );

/// 每页加载数量
const int _kPageSize = 20;

/// 单词本控制器
/// 编排 VocabularyBookQuery（只读）+ WordCommand（写入）
class VocabularyBookController extends Notifier<VocabularyBookState> {
  int? _userId;

  @override
  VocabularyBookState build() => const VocabularyBookState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  VocabularyBookQuery get _query => ref.read(vocabularyBookQueryProvider);
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

  /// 初始加载（进入页面时调用）
  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final userId = await _ensureUserId();

      // 并行加载：两个 tab 的首页数据 + 数量统计
      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final results = await Future.wait([
        _query.getVocabularyBookItems(
          userId: userId,
          status: LearningStatus.learning,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _query.getVocabularyBookItems(
          userId: userId,
          status: LearningStatus.mastered,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _query.getStatusCounts(userId: userId, searchQuery: searchQuery),
      ]);

      final learningWords = results[0] as List;
      final masteredWords = results[1] as List;
      final counts = results[2] as Map<LearningStatus, int>;

      state = state.copyWith(
        isLoading: false,
        learningWords: List.from(learningWords),
        masteredWords: List.from(masteredWords),
        learningCount: counts[LearningStatus.learning] ?? 0,
        masteredCount: counts[LearningStatus.mastered] ?? 0,
        hasMoreLearning: learningWords.length >= _kPageSize,
        hasMoreMastered: masteredWords.length >= _kPageSize,
      );

      logger.debug(
        '单词本加载完成: 学习中=${learningWords.length}, 已掌握=${masteredWords.length}',
      );
    } catch (e, stackTrace) {
      logger.error('单词本加载失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 加载更多（当前 Tab 的分页）
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.currentHasMore) return;

    try {
      state = state.copyWith(isLoadingMore: true);
      final userId = await _ensureUserId();
      final currentList = state.currentList;
      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final moreItems = await _query.getVocabularyBookItems(
        userId: userId,
        status: state.currentStatus,
        limit: _kPageSize,
        offset: currentList.length,
        searchQuery: searchQuery,
      );

      if (state.currentTabIndex == 0) {
        state = state.copyWith(
          isLoadingMore: false,
          learningWords: [...state.learningWords, ...moreItems],
          hasMoreLearning: moreItems.length >= _kPageSize,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          masteredWords: [...state.masteredWords, ...moreItems],
          hasMoreMastered: moreItems.length >= _kPageSize,
        );
      }

      logger.debug('加载更多: ${moreItems.length}条 (tab=${state.currentTabIndex})');
    } catch (e, stackTrace) {
      logger.error('加载更多失败', e, stackTrace);
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 切换 Tab
  void switchTab(int index) {
    if (index == state.currentTabIndex) return;
    state = state.copyWith(currentTabIndex: index);
  }

  /// 搜索
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadInitial();
  }

  /// 切换单词状态（学习中 ↔ 已掌握）
  Future<void> toggleStatus(int wordId) async {
    try {
      final userId = await _ensureUserId();

      if (state.currentTabIndex == 0) {
        // 学习中 → 已掌握
        await _wordCommand.markWordAsMastered(userId, wordId);
        logger.info('[VocabularyBook] 标记为已掌握: wordId=$wordId');
      } else {
        // 已掌握 → 学习中
        await _wordCommand.addWordToReview(userId, wordId);
        logger.info('[VocabularyBook] 恢复学习: wordId=$wordId');
      }

      // 重新加载数据以刷新两个 Tab 的列表和数量
      await loadInitial();
    } catch (e, stackTrace) {
      logger.error('切换状态失败', e, stackTrace);
    }
  }
}
