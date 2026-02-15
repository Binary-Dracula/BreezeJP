import '../../../data/models/grammar.dart';

class GrammarListState {
  final List<Grammar> grammars;
  final bool isLoading;
  final String? selectedLevel; // N5, N4, etc. or null for all
  final String? error;

  const GrammarListState({
    this.grammars = const [],
    this.isLoading = false,
    this.selectedLevel,
    this.error,
  });

  GrammarListState copyWith({
    List<Grammar>? grammars,
    bool? isLoading,
    String? selectedLevel,
    String? error,
  }) {
    return GrammarListState(
      grammars: grammars ?? this.grammars,
      isLoading: isLoading ?? this.isLoading,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      error: error,
    );
  }
}
