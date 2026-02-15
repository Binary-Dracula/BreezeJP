class WordConjugation {
  final int id;
  final int wordId;
  final int typeId;
  final String conjugatedWord;
  final String? furigana;
  final String? accentPattern;

  // Optional: associated type info for UI display
  final String? typeNameJa;
  final String? typeNameCn;

  WordConjugation({
    required this.id,
    required this.wordId,
    required this.typeId,
    required this.conjugatedWord,
    this.furigana,
    this.accentPattern,
    this.typeNameJa,
    this.typeNameCn,
  });

  factory WordConjugation.fromMap(Map<String, dynamic> map) {
    return WordConjugation(
      id: map['id'] as int,
      wordId: map['word_id'] as int,
      typeId: map['type_id'] as int,
      conjugatedWord: map['conjugated_word'] as String,
      furigana: map['furigana'] as String?,
      accentPattern: map['accent_pattern'] as String?,
      typeNameJa: map['name_ja'] as String?,
      typeNameCn: map['name_cn'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'type_id': typeId,
      'conjugated_word': conjugatedWord,
      'furigana': furigana,
      'accent_pattern': accentPattern,
    };
  }
}
