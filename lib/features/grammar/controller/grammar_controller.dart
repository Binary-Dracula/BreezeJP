import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/grammar_command.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/models/user.dart';
import '../../../data/models/grammar_detail.dart';
import '../../../data/queries/grammar_read_queries.dart';
import '../state/grammar_state.dart';

final grammarControllerProvider =
    NotifierProvider<GrammarController, GrammarState>(GrammarController.new);

class GrammarController extends Notifier<GrammarState> {
  int? _userId;

  @override
  GrammarState build() {
    return const GrammarState();
  }

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  GrammarCommand get _grammarCommand => ref.read(grammarCommandProvider);
  GrammarReadQueries get _grammarQueries =>
      ref.read(grammarReadQueriesProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  /// 初始化学习 (加载指定语法)
  Future<void> initWithGrammar(int grammarId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = await _ensureUserId();
      final detail = await _grammarQueries.getGrammarDetail(userId, grammarId);

      if (detail == null) {
        state = state.copyWith(isLoading: false, error: '语法不存在');
        return;
      }

      state = state.copyWith(
        studyQueue: [detail],
        currentIndex: 0,
        isLoading: false,
      );

      logger.info('Grammar loaded: ${detail.grammar.title}');

      // 预加载更多
      await loadMoreGrammars();
    } catch (e, stackTrace) {
      logger.error('Failed to init grammar', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载更多未学习的语法
  Future<void> loadMoreGrammars() async {
    if (state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final userId = await _ensureUserId();
      final currentIds = state.studyQueue.map((g) => g.grammar.id).toList();

      final newGrammars = await _grammarQueries.getUnlearnedGrammars(
        userId: userId,
        limit: 5,
        excludeIds: currentIds,
      );

      if (newGrammars.isEmpty) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final newDetails = <GrammarDetail>[];
      for (final grammar in newGrammars) {
        final detail = await _grammarQueries.getGrammarDetail(
          userId,
          grammar.id,
        );
        if (detail != null) {
          newDetails.add(detail);
        }
      }

      state = state.copyWith(
        studyQueue: [...state.studyQueue, ...newDetails],
        isLoadingMore: false,
      );
    } catch (e, stackTrace) {
      logger.error('Failed to load more grammars', e, stackTrace);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 页面切换
  void onPageChanged(int index) {
    state = state.copyWith(currentIndex: index);

    // 如果接近末尾，加载更多
    if (index >= state.studyQueue.length - 2) {
      loadMoreGrammars();
    }
  }

  /// 加入复习 (Seen -> Learning)
  Future<void> addToReview() async {
    final currentStr = state.currentGrammarDetail;
    if (currentStr == null) return;

    final userId = await _ensureUserId();
    await _grammarCommand.startLearning(userId, currentStr.grammar.id);
    await _refreshCurrentState();
  }

  /// 标记已掌握 (-> Mastered)
  Future<void> markAsMastered() async {
    final currentStr = state.currentGrammarDetail;
    if (currentStr == null) return;

    final userId = await _ensureUserId();
    await _grammarCommand.markAsMastered(userId, currentStr.grammar.id);
    await _refreshCurrentState();
  }

  Future<void> _refreshCurrentState() async {
    final currentIndex = state.currentIndex;
    final currentItem = state.studyQueue[currentIndex];
    final userId = await _ensureUserId();

    final updated = await _grammarQueries.getGrammarDetail(
      userId,
      currentItem.grammar.id,
    );
    if (updated == null) return;

    final newQueue = List<GrammarDetail>.from(state.studyQueue);
    newQueue[currentIndex] = updated;

    state = state.copyWith(studyQueue: newQueue);
  }
}
