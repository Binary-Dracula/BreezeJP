import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';

enum ReviewQuestionType {
  hiraganaToRomaji, // 看平假名选罗马音
  romajiToHiragana, // 看罗马音选平假名
  katakanaToRomaji, // 看片假名选罗马音
  romajiToKatakana, // 看罗马音选片假名
  hiraganaToKatakana, // 看平假名选片假名
  katakanaToHiragana, // 看片假名选平假名
}

/// 读音回忆模式的复习条目
class ReviewKanaItem {
  final KanaLetter kanaLetter;
  final KanaLearningState learningState;
  final String? audioFilename;
  final ReviewQuestionType questionType;
  final List<String> options;

  /// switchMode 题型使用：配对的对应假名（平假名 ↔ 片假名）
  final KanaLetter? counterpartLetter;

  ReviewKanaItem({
    required this.kanaLetter,
    required this.learningState,
    this.audioFilename,
    required this.questionType,
    required this.options,
    this.counterpartLetter,
  });
}

ReviewQuestionType reviewQuestionTypeFromApi(String value) {
  switch (value) {
    case 'romaji_to_hiragana':
      return ReviewQuestionType.romajiToHiragana;
    case 'katakana_to_romaji':
      return ReviewQuestionType.katakanaToRomaji;
    case 'romaji_to_katakana':
      return ReviewQuestionType.romajiToKatakana;
    case 'hiragana_to_katakana':
      return ReviewQuestionType.hiraganaToKatakana;
    case 'katakana_to_hiragana':
      return ReviewQuestionType.katakanaToHiragana;
    case 'hiragana_to_romaji':
    default:
      return ReviewQuestionType.hiraganaToRomaji;
  }
}
