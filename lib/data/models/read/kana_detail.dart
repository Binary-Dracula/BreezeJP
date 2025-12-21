import '../kana_audio.dart';
import '../kana_example.dart';
import '../kana_learning_state.dart';
import '../kana_letter.dart';
import '../kana_stroke_order.dart';

class KanaDetail {
  final KanaLetter letter;
  final KanaAudio? audio;
  final List<KanaExample> examples;
  final KanaLearningState? learningState;
  final KanaStrokeOrder? strokeOrder;

  KanaDetail({
    required this.letter,
    this.audio,
    this.examples = const [],
    this.learningState,
    this.strokeOrder,
  });
}

class KanaLetterWithState {
  final KanaLetter letter;
  final KanaLearningState? learningState;

  KanaLetterWithState({required this.letter, this.learningState});

  bool get isMastered => learningState?.isMastered ?? false;

  bool get isLearning => learningState?.isLearning ?? false;
}
