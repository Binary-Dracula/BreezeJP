import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/word_read_queries.dart';
import '../state/initial_choice_state.dart';

/// 初始选择页控制器
/// 管理初始选择页的状态和业务逻辑
class InitialChoiceController extends Notifier<InitialChoiceState> {
  @override
  InitialChoiceState build() {
    return const InitialChoiceState();
  }

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  /// 加载 5 个随机未掌握单词
  Future<void> loadChoices() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = (await _getActiveUser()).id;
      final wordQueries = ref.read(wordReadQueriesProvider);
      final choices = await wordQueries.getRandomUnmasteredWordsWithMeaning(
        userId: userId,
        count: 5,
      );

      state = state.copyWith(choices: choices, isLoading: false);

      logger.info('初始选择页加载完成: ${choices.length} 个单词');
    } catch (e, stackTrace) {
      logger.error('初始选择页加载失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 刷新选择（重新随机获取 5 个单词）
  Future<void> refresh() async {
    await loadChoices();
  }
}

/// InitialChoiceController Provider
final initialChoiceControllerProvider =
    NotifierProvider<InitialChoiceController, InitialChoiceState>(
      InitialChoiceController.new,
    );
