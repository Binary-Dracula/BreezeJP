import '../../core/network/api_endpoints.dart';

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

  static const Set<String> _placeholderValues = {
    'n/a',
    'na',
    'none',
    'null',
    'nil',
  };

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as String,
      word: _normalizedRequiredString(map['word']),
      reading: _normalizedString(map['reading']) ?? '',
      romaji: _normalizedString(map['romaji']),
      pitchAccent: _normalizedString(map['pitch_accent']),
      jlptLevel: _normalizedString(map['jlpt_level'])?.toUpperCase(),
      partOfSpeech: _normalizedString(map['part_of_speech']) ?? '',
      transitivity: _normalizedString(map['transitivity']),
      primaryMeaning: _normalizedString(map['primary_meaning']),
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
      word: _normalizedRequiredString(json['word']),
      reading: _normalizedString(json['reading']) ?? '',
      romaji: _normalizedString(json['romaji']),
      pitchAccent: _normalizedString(json['pitch_accent']),
      jlptLevel: _normalizedString(json['jlpt_level'])?.toUpperCase(),
      partOfSpeech: _normalizedString(json['part_of_speech']) ?? '',
      transitivity: _normalizedString(json['transitivity']),
      primaryMeaning: _normalizedString(json['primary_meaning']),
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

  String? get audioSource {
    if (!hasAudio) return null;
    return '${ApiEndpoints.baseUrl}${ApiEndpoints.replaceParams(ApiEndpoints.wordAudio, {'id': id})}';
  }

  static String _normalizedRequiredString(dynamic value) {
    return _normalizedString(value) ?? '';
  }

  static String? _normalizedString(dynamic value) {
    if (value == null) return null;
    final normalized = value is String ? value.trim() : value.toString().trim();
    if (normalized.isEmpty) return null;
    if (_placeholderValues.contains(normalized.toLowerCase())) return null;
    return normalized;
  }
}
