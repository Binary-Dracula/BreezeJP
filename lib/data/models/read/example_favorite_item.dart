class ExampleFavoriteItem {
  const ExampleFavoriteItem({
    required this.exampleId,
    required this.wordId,
    required this.word,
    required this.reading,
    required this.japanese,
    required this.chinese,
    required this.hasAudio,
    required this.updatedAt,
    this.jlptLevel,
    this.partOfSpeech,
    this.primaryMeaning,
  });

  final String exampleId;
  final String wordId;
  final String word;
  final String reading;
  final String japanese;
  final String chinese;
  final bool hasAudio;
  final DateTime updatedAt;
  final String? jlptLevel;
  final String? partOfSpeech;
  final String? primaryMeaning;

  factory ExampleFavoriteItem.fromJson(Map<String, dynamic> json) {
    return ExampleFavoriteItem(
      exampleId: json['example_id'] as String,
      wordId: json['word_id'] as String,
      word: json['word'] as String,
      reading: (json['reading'] as String?) ?? '',
      japanese: json['japanese'] as String,
      chinese: (json['chinese'] as String?) ?? '',
      hasAudio: json['has_audio'] == true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['updated_at'] as int?) ?? 0) * 1000,
      ),
      jlptLevel: json['jlpt_level'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      primaryMeaning: json['primary_meaning'] as String?,
    );
  }
}
