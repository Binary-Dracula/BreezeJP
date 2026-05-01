import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/grammar_command.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/study_remote_query.dart';
import '../../../data/queries/study_remote_query_provider.dart';
import '../../grammar/providers/grammar_status_refresh_provider.dart';
import '../state/grammar_book_state.dart';

/// 语法本页控制器 Provider
final grammarBookControllerProvider =
    NotifierProvider<GrammarBookController, GrammarBookState>(
      GrammarBookController.new,
    );

/// 每页加载数量
const int _kPageSize = 20;

/// 语法本控制器
class GrammarBookController extends Notifier<GrammarBookState> {
  int? _userId;

  @override
  GrammarBookState build() => const GrammarBookState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  StudyRemoteQuery get _remoteQuery => ref.read(studyRemoteQueryProvider);
  GrammarCommand get _grammarCommand => ref.read(grammarCommandProvider);

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

      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final results = await Future.wait([
        _remoteQuery.fetchGrammarBook(
          status: LearningStatus.learning,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _remoteQuery.fetchGrammarBook(
          status: LearningStatus.mastered,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
      ]);

      final learningPage = results[0];
      final masteredPage = results[1];

      state = state.copyWith(
        isLoading: false,
        learningGrammars: List.from(learningPage.items),
        masteredGrammars: List.from(masteredPage.items),
        learningCount: learningPage.totalCount,
        masteredCount: masteredPage.totalCount,
        hasMoreLearning: learningPage.hasMore,
        hasMoreMastered: masteredPage.hasMore,
      );

      logger.info(
        '语法本加载完成: 学习中=${learningPage.items.length}, 已掌握=${masteredPage.items.length}',
      );
    } catch (e, stackTrace) {
      logger.error('语法本加载失败', e, stackTrace);
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

      final response = await _remoteQuery.fetchGrammarBook(
        status: state.currentStatus,
        limit: _kPageSize,
        offset: currentList.length,
        searchQuery: searchQuery,
      );
      final moreItems = response.items;

      if (state.currentTabIndex == 0) {
        state = state.copyWith(
          isLoadingMore: false,
          learningGrammars: [...state.learningGrammars, ...moreItems],
          hasMoreLearning: response.hasMore,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          masteredGrammars: [...state.masteredGrammars, ...moreItems],
          hasMoreMastered: response.hasMore,
        );
      }
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

  /// 切换状态（学习中 ↔ 已掌握）
  Future<void> toggleStatus(int grammarId) async {
    try {
      final userId = await _ensureUserId();

      if (state.currentTabIndex == 0) {
        // 学习中 → 已掌握
        await _grammarCommand.markAsMastered(userId, grammarId);
      } else {
        // 已掌握 → 学习中
        await _grammarCommand.restoreToLearning(userId, grammarId);
      }

      await loadInitial();
      ref.read(grammarStatusRefreshProvider.notifier).bump();
    } catch (e, stackTrace) {
      logger.error('切换语法状态失败', e, stackTrace);
    }
  }
}
