import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grammar_repository.dart';

final grammarRepositoryProvider = Provider<GrammarRepository>((ref) {
  return GrammarRepository();
});
