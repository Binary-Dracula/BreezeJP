import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grammar_meaning_repository.dart';

final grammarMeaningRepositoryProvider = Provider<GrammarMeaningRepository>((
  ref,
) {
  return GrammarMeaningRepository();
});
