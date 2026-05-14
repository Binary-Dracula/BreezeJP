import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/favorite_command.dart';
import '../../../data/commands/favorite_command_provider.dart';
import '../../../data/commands/study_word_command.dart';
import '../../../data/models/read/vocabulary_book_item.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/study_remote_query.dart';
import '../../../data/queries/study_remote_query_provider.dart';
import '../state/vocabulary_book_state.dart';

/// 单词本页控制器 Provider
final vocabularyBookControllerProvider =
    NotifierProvider<VocabularyBookController, VocabularyBookState>(
      VocabularyBookController.new,
    );

/// 每页加载数量
const int _kPageSize = 20;

/// 单词本控制器
/// 编排远端单词本读取与状态写入。
class VocabularyBookController extends Notifier<VocabularyBookState> {
  int? _userId;

  @override
  VocabularyBookState build() => const VocabularyBookState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyRemoteQuery get _remoteQuery => ref.read(studyRemoteQueryProvider);
  StudyWordCommand get _studyWordCommand => ref.read(studyWordCommandProvider);
  FavoriteCommand get _favoriteCommand => ref.read(favoriteCommandProvider);

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
      await _ensureUserId();

      // 并行加载：两个 tab 的首页数据 + 数量统计
      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final results = await Future.wait([
        _remoteQuery.fetchWordBook(
          status: LearningStatus.learning,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _remoteQuery.fetchWordBook(
          status: LearningStatus.mastered,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _remoteQuery.fetchWordBook(
          status: LearningStatus.ignored,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _remoteQuery.fetchWordFavorites(
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
      ]);

      final learningPage = results[0];
      final masteredPage = results[1];
      final ignoredPage = results[2];
      final favoritePage = results[3];

      state = state.copyWith(
        isLoading: false,
        learningWords: List.from(learningPage.items),
        masteredWords: List.from(masteredPage.items),
        ignoredWords: List.from(ignoredPage.items),
        favoriteWords: List.from(favoritePage.items),
        learningCount: learningPage.totalCount,
        masteredCount: masteredPage.totalCount,
        ignoredCount: ignoredPage.totalCount,
        favoriteCount: favoritePage.totalCount,
        hasMoreLearning: learningPage.hasMore,
        hasMoreMastered: masteredPage.hasMore,
        hasMoreIgnored: ignoredPage.hasMore,
        hasMoreFavorites: favoritePage.hasMore,
      );

      logger.debug(
        '单词本加载完成: 学习中=${learningPage.items.length}, 已掌握=${masteredPage.items.length}, 已忽略=${ignoredPage.items.length}, 收藏=${favoritePage.items.length}',
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
      await _ensureUserId();
      final currentList = state.currentList;
      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final response = await switch (state.currentTabIndex) {
        0 => _remoteQuery.fetchWordBook(
          status: LearningStatus.learning,
          limit: _kPageSize,
          offset: currentList.length,
          searchQuery: searchQuery,
        ),
        1 => _remoteQuery.fetchWordBook(
          status: LearningStatus.mastered,
          limit: _kPageSize,
          offset: currentList.length,
          searchQuery: searchQuery,
        ),
        2 => _remoteQuery.fetchWordBook(
          status: LearningStatus.ignored,
          limit: _kPageSize,
          offset: currentList.length,
          searchQuery: searchQuery,
        ),
        _ => _remoteQuery.fetchWordFavorites(
          limit: _kPageSize,
          offset: currentList.length,
          searchQuery: searchQuery,
        ),
      };
      final moreItems = response.items;

      if (state.currentTabIndex == 0) {
        state = state.copyWith(
          isLoadingMore: false,
          learningWords: [...state.learningWords, ...moreItems],
          hasMoreLearning: response.hasMore,
        );
      } else if (state.currentTabIndex == 1) {
        state = state.copyWith(
          isLoadingMore: false,
          masteredWords: [...state.masteredWords, ...moreItems],
          hasMoreMastered: response.hasMore,
        );
      } else if (state.currentTabIndex == 2) {
        state = state.copyWith(
          isLoadingMore: false,
          ignoredWords: [...state.ignoredWords, ...moreItems],
          hasMoreIgnored: response.hasMore,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          favoriteWords: [...state.favoriteWords, ...moreItems],
          hasMoreFavorites: response.hasMore,
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
  Future<void> toggleStatus(VocabularyBookItem item) async {
    try {
      final userId = await _ensureUserId();

      if (state.currentTabIndex == 0) {
        // 学习中 → 已掌握
        await _studyWordCommand.markAsMastered(
          userId: userId,
          wordId: item.wordId,
          bookId: item.bookId,
        );
        logger.info('[VocabularyBook] 标记为已掌握: wordId=${item.wordId}');
      } else if (state.currentTabIndex == 3) {
        await _favoriteCommand.removeWordFavorite(wordId: item.wordId);
        logger.info('[VocabularyBook] 取消收藏: wordId=${item.wordId}');
      } else {
        // 已掌握/已忽略 → 学习中
        await _studyWordCommand.restoreToLearning(
          userId: userId,
          wordId: item.wordId,
          bookId: item.bookId,
        );
        logger.info('[VocabularyBook] 恢复学习: wordId=${item.wordId}');
      }

      // 重新加载数据以刷新两个 Tab 的列表和数量
      await loadInitial();
    } catch (e, stackTrace) {
      logger.error('切换状态失败', e, stackTrace);
    }
  }
}
