import 'grammar_example.dart';

/// 语法义项（一条语法可以有多个义项）
class GrammarMeaning {
  final int id;
  final int grammarId;
  final int sortOrder;
  final String? connection;
  final String? meaning;
  final String? tip;

  /// 嵌套的例句列表（由 Query 层填充）
  final List<GrammarExample> examples;

  GrammarMeaning({
    required this.id,
    required this.grammarId,
    required this.sortOrder,
    this.connection,
    this.meaning,
    this.tip,
    this.examples = const [],
  });

  factory GrammarMeaning.fromMap(Map<String, dynamic> map) {
    return GrammarMeaning(
      id: map['id'] as int,
      grammarId: map['grammar_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 1,
      connection: map['connection'] as String?,
      meaning: map['meaning'] as String?,
      tip: map['tip'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grammar_id': grammarId,
      'sort_order': sortOrder,
      'connection': connection,
      'meaning': meaning,
      'tip': tip,
    };
  }

  GrammarMeaning copyWith({
    int? id,
    int? grammarId,
    int? sortOrder,
    String? connection,
    String? meaning,
    String? tip,
    List<GrammarExample>? examples,
  }) {
    return GrammarMeaning(
      id: id ?? this.id,
      grammarId: grammarId ?? this.grammarId,
      sortOrder: sortOrder ?? this.sortOrder,
      connection: connection ?? this.connection,
      meaning: meaning ?? this.meaning,
      tip: tip ?? this.tip,
      examples: examples ?? this.examples,
    );
  }
}
