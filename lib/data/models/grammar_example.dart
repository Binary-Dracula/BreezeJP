class GrammarExample {
  final int id;
  final int grammarId;
  final String? sentence;
  final String? translation;
  final String? audioUrl;
  final DateTime createdAt;

  GrammarExample({
    required this.id,
    required this.grammarId,
    this.sentence,
    this.translation,
    this.audioUrl,
    required this.createdAt,
  });

  factory GrammarExample.fromMap(Map<String, dynamic> map) {
    return GrammarExample(
      id: map['id'] as int,
      grammarId: map['grammar_id'] as int,
      sentence: map['sentence'] as String?,
      translation: map['translation'] as String?,
      audioUrl: map['audio_url'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grammar_id': grammarId,
      'sentence': sentence,
      'translation': translation,
      'audio_url': audioUrl,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  GrammarExample copyWith({
    int? id,
    int? grammarId,
    String? sentence,
    String? translation,
    String? audioUrl,
    DateTime? createdAt,
  }) {
    return GrammarExample(
      id: id ?? this.id,
      grammarId: grammarId ?? this.grammarId,
      sentence: sentence ?? this.sentence,
      translation: translation ?? this.translation,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
