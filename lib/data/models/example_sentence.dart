class ExampleSentence {
  final int id;
  final int wordId;
  final String sentenceJp;
  final String? sentenceFurigana;
  final String? translationCn;
  final String? notes;

  ExampleSentence({
    required this.id,
    required this.wordId,
    required this.sentenceJp,
    this.sentenceFurigana,
    this.translationCn,
    this.notes,
  });

  factory ExampleSentence.fromMap(Map<String, dynamic> map) {
    return ExampleSentence(
      id: map['id'],
      wordId: map['word_id'],
      sentenceJp: map['sentence_jp'],
      sentenceFurigana: map['sentence_furigana'],
      translationCn: map['translation_cn'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'sentence_jp': sentenceJp,
      'sentence_furigana': sentenceFurigana,
      'translation_cn': translationCn,
      'notes': notes,
    };
  }
}
