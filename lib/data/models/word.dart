/// 单词主表模型（2.0 — UUID 主键，对齐 Supabase）
class Word {
  final String id;
  final String word;
  final String reading;
  final String? romaji;
  final String? pitchAccent;
  final String? jlptLevel;
  final String partOfSpeech;
  final String? transitivity;
  final String? primaryMeaning;
  final bool hasAudio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Word({
    required this.id,
    required this.word,
    required this.reading,
    this.romaji,
    this.pitchAccent,
    this.jlptLevel,
    required this.partOfSpeech,
    this.transitivity,
    this.primaryMeaning,
    this.hasAudio = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as String,
      word: map['word'] as String,
      reading: (map['reading'] as String?) ?? '',
      romaji: map['romaji'] as String?,
      pitchAccent: map['pitch_accent'] as String?,
      jlptLevel: map['jlpt_level'] as String?,
      partOfSpeech: (map['part_of_speech'] as String?) ?? '',
      transitivity: map['transitivity'] as String?,
      primaryMeaning: map['primary_meaning'] as String?,
      hasAudio: (map['has_audio'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['created_at'] as int) * 1000,
            )
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['updated_at'] as int) * 1000,
            )
          : null,
    );
  }

  /// 从 Supabase API JSON 创建（时间戳为 ISO8601）
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: (json['reading'] as String?) ?? '',
      romaji: json['romaji'] as String?,
      pitchAccent: json['pitch_accent'] as String?,
      jlptLevel: json['jlpt_level'] as String?,
      partOfSpeech: (json['part_of_speech'] as String?) ?? '',
      transitivity: json['transitivity'] as String?,
      primaryMeaning: json['primary_meaning'] as String?,
      hasAudio: json['has_audio'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'reading': reading,
      'romaji': romaji,
      'pitch_accent': pitchAccent,
      'jlpt_level': jlptLevel,
      'part_of_speech': partOfSpeech,
      'transitivity': transitivity,
      'primary_meaning': primaryMeaning,
      'has_audio': hasAudio ? 1 : 0,
      'updated_at': updatedAt != null
          ? updatedAt!.millisecondsSinceEpoch ~/ 1000
          : (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    };
  }
}
