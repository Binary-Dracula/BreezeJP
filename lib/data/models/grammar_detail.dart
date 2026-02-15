import 'grammar.dart';
import 'grammar_example.dart';
import '../../core/constants/learning_status.dart';

/// 语法详情（包含关联数据）
class GrammarDetail {
  final Grammar grammar;
  final List<GrammarExample> examples;
  final LearningStatus userState;

  GrammarDetail({
    required this.grammar,
    required this.examples,
    this.userState = LearningStatus.seen,
  });

  GrammarDetail copyWith({
    Grammar? grammar,
    List<GrammarExample>? examples,
    LearningStatus? userState,
  }) {
    return GrammarDetail(
      grammar: grammar ?? this.grammar,
      examples: examples ?? this.examples,
      userState: userState ?? this.userState,
    );
  }
}
