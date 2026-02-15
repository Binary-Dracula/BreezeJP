import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grammar_example_repository.dart';

final grammarExampleRepositoryProvider = Provider<GrammarExampleRepository>((
  ref,
) {
  return GrammarExampleRepository();
});
