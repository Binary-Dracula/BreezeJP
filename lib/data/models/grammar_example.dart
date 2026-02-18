class GrammarExample {
  final int id;
  final int meaningId;
  final int sortOrder;
  final String? sentence;
  final String? translation;
  final bool isTipExample;
  final String? audioUrl;

  GrammarExample({
    required this.id,
    required this.meaningId,
    required this.sortOrder,
    this.sentence,
    this.translation,
    this.isTipExample = false,
    this.audioUrl,
  });

  factory GrammarExample.fromMap(Map<String, dynamic> map) {
    return GrammarExample(
      id: map['id'] as int,
      meaningId: map['meaning_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 1,
      sentence: map['sentence'] as String?,
      translation: map['translation'] as String?,
      isTipExample: (map['is_tip_example'] as int? ?? 0) == 1,
      audioUrl: map['audio_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meaning_id': meaningId,
      'sort_order': sortOrder,
      'sentence': sentence,
      'translation': translation,
      'is_tip_example': isTipExample ? 1 : 0,
      'audio_url': audioUrl,
    };
  }

  GrammarExample copyWith({
    int? id,
    int? meaningId,
    int? sortOrder,
    String? sentence,
    String? translation,
    bool? isTipExample,
    String? audioUrl,
  }) {
    return GrammarExample(
      id: id ?? this.id,
      meaningId: meaningId ?? this.meaningId,
      sortOrder: sortOrder ?? this.sortOrder,
      sentence: sentence ?? this.sentence,
      translation: translation ?? this.translation,
      isTipExample: isTipExample ?? this.isTipExample,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}
