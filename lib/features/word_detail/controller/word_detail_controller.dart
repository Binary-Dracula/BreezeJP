import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/queries/word_detail_remote_query.dart';
import '../state/word_detail_state.dart';

final wordDetailControllerProvider =
    NotifierProvider<WordDetailController, WordDetailState>(
      WordDetailController.new,
    );

class WordDetailController extends Notifier<WordDetailState> {
  @override
  WordDetailState build() => const WordDetailState();

  WordDetailRemoteQuery get _remoteQuery =>
      ref.read(wordDetailRemoteQueryProvider);

  Future<void> loadWord(String wordId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final detail = await _remoteQuery.fetchWordDetail(wordId);

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
