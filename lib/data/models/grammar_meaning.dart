class GrammarMeaning {
  final int id;
  final int grammarId;
  final int sortOrder;
  final String? definitionCn;
  final String? definitionEn;
  final String? howToUseCn;
  final String? howToUseEn;

  GrammarMeaning({
    required this.id,
    required this.grammarId,
    required this.sortOrder,
    this.definitionCn,
    this.definitionEn,
    this.howToUseCn,
    this.howToUseEn,
  });

  factory GrammarMeaning.fromMap(Map<String, dynamic> map) {
    return GrammarMeaning(
      id: map['id'] as int,
      grammarId: map['grammar_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 1,
      definitionCn: map['definition_cn'] as String?,
      definitionEn: map['definition_en'] as String?,
      howToUseCn: map['how_to_use_cn'] as String?,
      howToUseEn: map['how_to_use_en'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grammar_id': grammarId,
      'sort_order': sortOrder,
      'definition_cn': definitionCn,
      'definition_en': definitionEn,
      'how_to_use_cn': howToUseCn,
      'how_to_use_en': howToUseEn,
    };
  }

  GrammarMeaning copyWith({
    int? id,
    int? grammarId,
    int? sortOrder,
    String? definitionCn,
    String? definitionEn,
    String? howToUseCn,
    String? howToUseEn,
  }) {
    return GrammarMeaning(
      id: id ?? this.id,
      grammarId: grammarId ?? this.grammarId,
      sortOrder: sortOrder ?? this.sortOrder,
      definitionCn: definitionCn ?? this.definitionCn,
      definitionEn: definitionEn ?? this.definitionEn,
      howToUseCn: howToUseCn ?? this.howToUseCn,
      howToUseEn: howToUseEn ?? this.howToUseEn,
    );
  }
}
