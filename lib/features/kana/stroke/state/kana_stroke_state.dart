import '../../../../data/models/kana_detail.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../chart/state/kana_chart_state.dart';

const _unset = Object();

/// 假名笔顺练习状态
class KanaStrokeState {
  final bool isLoading;
  final String? error;
  final List<KanaLetterWithState> kanaLetters;
  final int currentIndex;
  final KanaDisplayMode displayMode;
  final String? svgData;
  final String? audioFilename;
  final KanaLearningState? learningState;

  const KanaStrokeState({
    this.isLoading = false,
    this.error,
    this.kanaLetters = const [],
    this.currentIndex = 0,
    this.displayMode = KanaDisplayMode.hiragana,
    this.svgData,
    this.audioFilename,
    this.learningState,
  });

  bool get hasError => error != null;

  KanaLetterWithState? get currentKana =>
      currentIndex < kanaLetters.length ? kanaLetters[currentIndex] : null;

  bool get canGoPrev => currentIndex > 0;

  bool get canGoNext => currentIndex < kanaLetters.length - 1;

  KanaStrokeState copyWith({
    bool? isLoading,
    String? error,
    List<KanaLetterWithState>? kanaLetters,
    int? currentIndex,
    KanaDisplayMode? displayMode,
    KanaLearningState? learningState,
    Object? svgData = _unset,
    Object? audioFilename = _unset,
  }) {
    return KanaStrokeState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      kanaLetters: kanaLetters ?? this.kanaLetters,
      currentIndex: currentIndex ?? this.currentIndex,
      displayMode: displayMode ?? this.displayMode,
      learningState: learningState ?? this.learningState,
      svgData: identical(svgData, _unset) ? this.svgData : svgData as String?,
      audioFilename: identical(audioFilename, _unset)
          ? this.audioFilename
          : audioFilename as String?,
    );
  }
}
