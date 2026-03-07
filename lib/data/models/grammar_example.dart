class GrammarExample {
  final int id;
  final int grammarId;
  final int sortOrder;
  final String? sentence;
  final String? translationCn;
  final String? translationEn;
  final String? audioUrl;

  GrammarExample({
    required this.id,
    required this.grammarId,
    required this.sortOrder,
    this.sentence,
    this.translationCn,
    this.translationEn,
    this.audioUrl,
  });

  factory GrammarExample.fromMap(Map<String, dynamic> map) {
    return GrammarExample(
      id: map['id'] as int,
      grammarId: map['grammar_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 1,
      sentence: map['sentence'] as String?,
      translationCn: map['translation_cn'] as String?,
      translationEn: map['translation_en'] as String?,
      audioUrl: map['audio_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grammar_id': grammarId,
      'sort_order': sortOrder,
      'sentence': sentence,
      'translation_cn': translationCn,
      'translation_en': translationEn,
      'audio_url': audioUrl,
    };
  }

  GrammarExample copyWith({
    int? id,
    int? grammarId,
    int? sortOrder,
    String? sentence,
    String? translationCn,
    String? translationEn,
    String? audioUrl,
  }) {
    return GrammarExample(
      id: id ?? this.id,
      grammarId: grammarId ?? this.grammarId,
      sortOrder: sortOrder ?? this.sortOrder,
      sentence: sentence ?? this.sentence,
      translationCn: translationCn ?? this.translationCn,
      translationEn: translationEn ?? this.translationEn,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}
