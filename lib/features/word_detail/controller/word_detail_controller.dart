import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/models/user.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/word_read_queries.dart';
import '../state/word_detail_state.dart';

final wordDetailControllerProvider =
    NotifierProvider<WordDetailController, WordDetailState>(
      WordDetailController.new,
    );

class WordDetailController extends Notifier<WordDetailState> {
  int? _userId;

  @override
  WordDetailState build() => const WordDetailState();

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  WordReadQueries get _wordReadQueries => ref.read(wordReadQueriesProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  Future<void> loadWord(String wordId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = await _ensureUserId();
      final detail = await _wordReadQueries.getWordDetail(wordId, userId: userId);

      if (detail == null) {
        state = const WordDetailState(isLoading: false, error: '单词不存在');
        return;
      }

      state = WordDetailState(isLoading: false, detail: detail);
    } catch (e, stackTrace) {
      logger.error('Failed to load word detail: $wordId', e, stackTrace);
      state = WordDetailState(isLoading: false, error: e.toString());
    }
  }
}