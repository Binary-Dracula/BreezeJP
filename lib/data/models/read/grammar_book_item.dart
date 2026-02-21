import '../../../core/constants/learning_status.dart';

/// 语法本列表项（只读，用于列表展示）
/// JOIN study_grammars + grammars 的查询结果
class GrammarBookItem {
  final int studyGrammarId;
  final int grammarId;
  final String title;
  final String? jlptLevel;
  final LearningStatus userState;
  final DateTime updatedAt;

  const GrammarBookItem({
    required this.studyGrammarId,
    required this.grammarId,
    required this.title,
    this.jlptLevel,
    required this.userState,
    required this.updatedAt,
  });

  factory GrammarBookItem.fromMap(Map<String, dynamic> map) {
    return GrammarBookItem(
      studyGrammarId: map['study_grammar_id'] as int,
      grammarId: map['grammar_id'] as int,
      title: map['title'] as String,
      jlptLevel: map['jlpt_level'] as String?,
      userState: LearningStatus.fromValue(map['learning_status'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }
}
