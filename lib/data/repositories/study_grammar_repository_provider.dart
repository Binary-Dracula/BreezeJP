import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'study_grammar_repository.dart';

final studyGrammarRepositoryProvider = Provider<StudyGrammarRepository>((ref) {
  return StudyGrammarRepository();
});
