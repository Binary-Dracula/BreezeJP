import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/learning_status.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/commands/grammar_command.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/models/user.dart';
import '../../../data/models/grammar_detail.dart';
import '../../../data/queries/grammar_remote_query.dart';
import '../../../data/queries/grammar_remote_query_provider.dart';
import '../providers/grammar_status_refresh_provider.dart';
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
  GrammarRemoteQuery get _remoteQuery => ref.read(grammarRemoteQueryProvider);

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
      final detail = await _remoteQuery.fetchGrammarDetail(grammarId);

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
      final currentIds = state.studyQueue.map((g) => g.grammar.id).toList();

      final newDetails = await _remoteQuery.fetchGrammarLearningQueue(
        limit: 5,
        excludeIds: currentIds,
      );

      if (newDetails.isEmpty) {
        state = state.copyWith(isLoadingMore: false);
        return;
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
    _setCurrentUserState(LearningStatus.learning);
    _notifyStatusChanged();
  }

  /// 标记已掌握 (-> Mastered)
  Future<void> markAsMastered() async {
    final currentStr = state.currentGrammarDetail;
    if (currentStr == null) return;

    final userId = await _ensureUserId();
    await _grammarCommand.markAsMastered(userId, currentStr.grammar.id);
    _setCurrentUserState(LearningStatus.mastered);
    _notifyStatusChanged();
  }

  /// 恢复学习 (Mastered -> Learning)
  Future<void> restoreToLearning() async {
    final currentStr = state.currentGrammarDetail;
    if (currentStr == null) return;

    final userId = await _ensureUserId();
    await _grammarCommand.restoreToLearning(userId, currentStr.grammar.id);
    _setCurrentUserState(LearningStatus.learning);
    _notifyStatusChanged();
  }

  Future<void> resetToUnlearned() async {
    final currentStr = state.currentGrammarDetail;
    if (currentStr == null) return;

    final userId = await _ensureUserId();
    await _grammarCommand.setUnlearned(userId, currentStr.grammar.id);
    _setCurrentUserState(LearningStatus.unlearned);
    _notifyStatusChanged();
  }

  void _setCurrentUserState(LearningStatus status) {
    final currentIndex = state.currentIndex;
    final currentItem = state.studyQueue[currentIndex];

    final newQueue = List<GrammarDetail>.from(state.studyQueue);
    newQueue[currentIndex] = currentItem.copyWith(userState: status);

    state = state.copyWith(studyQueue: newQueue);
  }

  void _notifyStatusChanged() {
    ref.read(grammarStatusRefreshProvider.notifier).bump();
  }
}
