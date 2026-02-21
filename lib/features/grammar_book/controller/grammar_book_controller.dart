import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/grammar_command.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/grammar_book_query.dart';
import '../../../data/queries/grammar_book_query_provider.dart';
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
  GrammarBookQuery get _query => ref.read(grammarBookQueryProvider);
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
      final userId = await _ensureUserId();

      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final results = await Future.wait([
        _query.getGrammarBookItems(
          userId: userId,
          status: LearningStatus.learning,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _query.getGrammarBookItems(
          userId: userId,
          status: LearningStatus.mastered,
          limit: _kPageSize,
          offset: 0,
          searchQuery: searchQuery,
        ),
        _query.getStatusCounts(userId: userId, searchQuery: searchQuery),
      ]);

      final learningItems = results[0] as List;
      final masteredItems = results[1] as List;
      final counts = results[2] as Map<LearningStatus, int>;

      state = state.copyWith(
        isLoading: false,
        learningGrammars: List.from(learningItems),
        masteredGrammars: List.from(masteredItems),
        learningCount: counts[LearningStatus.learning] ?? 0,
        masteredCount: counts[LearningStatus.mastered] ?? 0,
        hasMoreLearning: learningItems.length >= _kPageSize,
        hasMoreMastered: masteredItems.length >= _kPageSize,
      );

      logger.info(
        '语法本加载完成: 学习中=${learningItems.length}, 已掌握=${masteredItems.length}',
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
      final userId = await _ensureUserId();
      final currentList = state.currentList;
      final searchQuery = state.searchQuery.isEmpty ? null : state.searchQuery;

      final moreItems = await _query.getGrammarBookItems(
        userId: userId,
        status: state.currentStatus,
        limit: _kPageSize,
        offset: currentList.length,
        searchQuery: searchQuery,
      );

      if (state.currentTabIndex == 0) {
        state = state.copyWith(
          isLoadingMore: false,
          learningGrammars: [...state.learningGrammars, ...moreItems],
          hasMoreLearning: moreItems.length >= _kPageSize,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          masteredGrammars: [...state.masteredGrammars, ...moreItems],
          hasMoreMastered: moreItems.length >= _kPageSize,
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
    } catch (e, stackTrace) {
      logger.error('切换语法状态失败', e, stackTrace);
    }
  }
}
