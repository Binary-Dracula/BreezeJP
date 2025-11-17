class WordMeaning {
  final int id;
  final int wordId;
  final String meaningCn;
  final int definitionOrder;
  final String? notes;

  WordMeaning({
    required this.id,
    required this.wordId,
    required this.meaningCn,
    required this.definitionOrder,
    this.notes,
  });

  factory WordMeaning.fromMap(Map<String, dynamic> map) {
    return WordMeaning(
      id: map['id'],
      wordId: map['word_id'],
      meaningCn: map['meaning_cn'],
      definitionOrder: map['definition_order'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'meaning_cn': meaningCn,
      'definition_order': definitionOrder,
      'notes': notes,
    };
  }
}
