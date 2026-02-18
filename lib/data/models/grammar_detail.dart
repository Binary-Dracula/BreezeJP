import 'grammar.dart';
import 'grammar_meaning.dart';
import '../../core/constants/learning_status.dart';

/// 语法详情（包含关联的义项和例句）
class GrammarDetail {
  final Grammar grammar;
  final List<GrammarMeaning> meanings;
  final LearningStatus userState;

  GrammarDetail({
    required this.grammar,
    required this.meanings,
    this.userState = LearningStatus.seen,
  });

  GrammarDetail copyWith({
    Grammar? grammar,
    List<GrammarMeaning>? meanings,
    LearningStatus? userState,
  }) {
    return GrammarDetail(
      grammar: grammar ?? this.grammar,
      meanings: meanings ?? this.meanings,
      userState: userState ?? this.userState,
    );
  }
}
