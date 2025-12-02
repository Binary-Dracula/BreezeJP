import 'kana_letter.dart';
import 'kana_audio.dart';
import 'kana_example.dart';
import 'kana_learning_state.dart';
import 'kana_stroke_order.dart';

/// 五十音完整详情模型
/// 包含假名字母、音频、示例、学习状态和笔顺
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

/// 带学习状态的假名字母（用于列表展示）
class KanaLetterWithState {
  final KanaLetter letter;
  final KanaLearningState? learningState;

  KanaLetterWithState({required this.letter, this.learningState});

  /// 是否已掌握
  bool get isMastered => learningState?.isMastered ?? false;

  /// 是否处于学习中（含掌握态）
  bool get isLearning => learningState?.isLearning ?? false;
}
