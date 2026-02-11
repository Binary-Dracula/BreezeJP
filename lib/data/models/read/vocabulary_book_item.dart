import '../../../core/constants/learning_status.dart';

/// 单词本列表项（只读，用于列表展示）
/// JOIN study_words + words + word_meanings + word_audios 的查询结果
class VocabularyBookItem {
  final int studyWordId;
  final int wordId;
  final String word;
  final String? furigana;
  final String? jlptLevel;
  final String? partOfSpeech;
  final String? primaryMeaning;
  final String? audioFilename;
  final String? audioUrl;
  final LearningStatus userState;
  final DateTime updatedAt;

  const VocabularyBookItem({
    required this.studyWordId,
    required this.wordId,
    required this.word,
    this.furigana,
    this.jlptLevel,
    this.partOfSpeech,
    this.primaryMeaning,
    this.audioFilename,
    this.audioUrl,
    required this.userState,
    required this.updatedAt,
  });

  factory VocabularyBookItem.fromMap(Map<String, dynamic> map) {
    return VocabularyBookItem(
      studyWordId: map['study_word_id'] as int,
      wordId: map['word_id'] as int,
      word: map['word'] as String,
      furigana: map['furigana'] as String?,
      jlptLevel: map['jlpt_level'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      primaryMeaning: map['primary_meaning'] as String?,
      audioFilename: map['audio_filename'] as String?,
      audioUrl: map['audio_url'] as String?,
      userState: LearningStatus.fromValue(map['user_state'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }
}
