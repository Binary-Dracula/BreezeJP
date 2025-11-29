import 'word.dart';

/// 带关联信息的单词
/// 用于关联词查询结果
class WordWithRelation {
  final Word word;
  final double score;
  final String relationType;

  const WordWithRelation({
    required this.word,
    required this.score,
    required this.relationType,
  });

  factory WordWithRelation.fromMap(Map<String, dynamic> map) {
    return WordWithRelation(
      word: Word.fromMap(map),
      score: (map['score'] as num).toDouble(),
      relationType: map['relation_type'] as String? ?? 'semantic',
    );
  }
}
