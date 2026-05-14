import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/grammar.dart';
import '../../../data/queries/grammar_remote_query.dart';
import '../../../data/queries/grammar_remote_query_provider.dart';
import '../state/grammar_list_state.dart';

final grammarListControllerProvider =
    NotifierProvider<GrammarListController, GrammarListState>(
      GrammarListController.new,
    );

class GrammarListController extends Notifier<GrammarListState> {
  static const _pageSize = 50;

  @override
  GrammarListState build() {
    return const GrammarListState(
      isLoading: true,
      selectedLevel: 'n5',
    ); // Default to n5
  }

  GrammarRemoteQuery get _remoteQuery => ref.read(grammarRemoteQueryProvider);

  Future<void> loadGrammars() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final grammars = await _fetchAllGrammars(state.selectedLevel);

      final counts = Map<String, int>.from(state.levelCounts);
      final selectedLevel = state.selectedLevel;
      if (selectedLevel != null) {
        counts[selectedLevel] = grammars.length;
      }

      state = state.copyWith(
        grammars: grammars,
        isLoading: false,
        levelCounts: counts,
      );
    } catch (e, stackTrace) {
      logger.error('Failed to load grammar list', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<Grammar>> _fetchAllGrammars(String? jlptLevel) async {
    final grammars = <Grammar>[];
    final excludedIds = <int>[];
    final seenIds = <int>{};

    while (true) {
      final page = await _remoteQuery.fetchGrammars(
        limit: _pageSize,
        excludeIds: excludedIds,
        jlptLevel: jlptLevel,
      );

      if (page.isEmpty) {
        break;
      }

      final newGrammars = <Grammar>[];
      for (final detail in page) {
        final grammar = detail.grammar;
        if (seenIds.add(grammar.id)) {
          newGrammars.add(grammar);
        }
      }

      if (newGrammars.isEmpty) {
        break;
      }

      grammars.addAll(newGrammars);
      excludedIds.addAll(newGrammars.map((grammar) => grammar.id));

      if (page.length < _pageSize) {
        break;
      }
    }

    return grammars;
  }

  void selectLevel(String? level) {
    if (state.selectedLevel == level) return;
    state = state.copyWith(selectedLevel: level);
    loadGrammars();
  }
}
