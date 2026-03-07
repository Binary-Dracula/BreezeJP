import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grammar_context_repository.dart';

final grammarContextRepositoryProvider = Provider<GrammarContextRepository>((
  ref,
) {
  return GrammarContextRepository();
});
