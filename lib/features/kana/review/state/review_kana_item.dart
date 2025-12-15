import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';

/// 读音回忆模式的复习条目
class ReviewKanaItem {
  final KanaLetter kanaLetter;
  final KanaLearningState learningState;
  final String? audioFilename;
  final ReviewQuestionType questionType;

  ReviewKanaItem({
    required this.kanaLetter,
    required this.learningState,
    this.audioFilename,
    required this.questionType,
  });
}

enum ReviewQuestionType { recall, audio, switchMode }
