import 'grammar.dart';
import 'grammar_meaning.dart';
import 'grammar_context.dart';
import 'grammar_example.dart';
import '../../core/constants/learning_status.dart';

/// 语法详情（封装供 View 层消费的对象）
class GrammarDetail {
  final Grammar grammar;
  final List<GrammarMeaning> meanings;
  final List<GrammarContext> contexts;
  final List<GrammarExample> examples;
  final LearningStatus userState;

  GrammarDetail({
    required this.grammar,
    required this.meanings,
    required this.contexts,
    required this.examples,
    this.userState = LearningStatus.unlearned,
  });

  GrammarDetail copyWith({
    Grammar? grammar,
    List<GrammarMeaning>? meanings,
    List<GrammarContext>? contexts,
    List<GrammarExample>? examples,
    LearningStatus? userState,
  }) {
    return GrammarDetail(
      grammar: grammar ?? this.grammar,
      meanings: meanings ?? this.meanings,
      contexts: contexts ?? this.contexts,
      examples: examples ?? this.examples,
      userState: userState ?? this.userState,
    );
  }
}
