import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/queries/grammar_read_queries.dart';
import '../state/grammar_list_state.dart';

final grammarListControllerProvider =
    NotifierProvider<GrammarListController, GrammarListState>(
      GrammarListController.new,
    );

class GrammarListController extends Notifier<GrammarListState> {
  @override
  GrammarListState build() {
    return const GrammarListState(
      isLoading: true,
      selectedLevel: 'N5',
    ); // Default to N5
  }

  GrammarReadQueries get _queries => ref.read(grammarReadQueriesProvider);

  Future<void> loadGrammars() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final grammars = await _queries.getGrammarList(
        jlptLevel: state.selectedLevel,
      );
      state = state.copyWith(grammars: grammars, isLoading: false);
    } catch (e, stackTrace) {
      logger.error('Failed to load grammar list', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectLevel(String? level) {
    if (state.selectedLevel == level) return;
    state = state.copyWith(selectedLevel: level);
    loadGrammars();
  }
}
