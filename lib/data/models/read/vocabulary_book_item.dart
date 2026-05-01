import '../../../core/network/api_endpoints.dart';
import '../../../core/constants/learning_status.dart';

/// 单词本列表项（只读，2.0 — JOIN study_words + words）
class VocabularyBookItem {
  final int studyWordId;
  final String wordId;
  final String bookId;
  final String word;
  final String reading;
  final String? jlptLevel;
  final String? partOfSpeech;
  final String? primaryMeaning;
  final bool hasAudio;
  final LearningStatus userState;
  final DateTime updatedAt;

  const VocabularyBookItem({
    required this.studyWordId,
    required this.wordId,
    required this.bookId,
    required this.word,
    required this.reading,
    this.jlptLevel,
    this.partOfSpeech,
    this.primaryMeaning,
    this.hasAudio = false,
    required this.userState,
    required this.updatedAt,
  });

  factory VocabularyBookItem.fromMap(Map<String, dynamic> map) {
    return VocabularyBookItem(
      studyWordId: map['study_word_id'] as int,
      wordId: map['word_id'] as String,
      bookId: map['book_id'] as String,
      word: map['word'] as String,
      reading: (map['reading'] as String?) ?? '',
      jlptLevel: map['jlpt_level'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      primaryMeaning: map['primary_meaning'] as String?,
      hasAudio: (map['has_audio'] as int?) == 1,
      userState: LearningStatus.fromValue(map['user_state'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  factory VocabularyBookItem.fromJson(Map<String, dynamic> json) {
    return VocabularyBookItem(
      studyWordId: (json['study_word_id'] as int?) ?? 0,
      wordId: json['word_id'] as String,
      bookId: json['book_id'] as String,
      word: json['word'] as String,
      reading: (json['reading'] as String?) ?? '',
      jlptLevel: json['jlpt_level'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      primaryMeaning: json['primary_meaning'] as String?,
      hasAudio: json['has_audio'] == true,
      userState: LearningStatus.fromValue((json['user_state'] as int?) ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['updated_at'] as int?) ?? 0) * 1000,
      ),
    );
  }

  String? get audioSource {
    if (!hasAudio) return null;
    return '${ApiEndpoints.baseUrl}${ApiEndpoints.replaceParams(ApiEndpoints.wordAudio, {'id': wordId})}';
  }
}
