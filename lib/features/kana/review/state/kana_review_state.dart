import 'package:meta/meta.dart';
import '../../../../data/models/kana_learning_state.dart';

@immutable
class KanaReviewState {
  final bool isLoading;
  final List<KanaLearningState> reviewList;
  final int currentIndex;
  final bool isFinished;
  final String? error;

  const KanaReviewState({
    this.isLoading = false,
    this.reviewList = const [],
    this.currentIndex = 0,
    this.isFinished = false,
    this.error,
  });

  KanaLearningState? get current =>
      (currentIndex >= 0 && currentIndex < reviewList.length)
      ? reviewList[currentIndex]
      : null;

  bool get hasError => error != null;

  KanaReviewState copyWith({
    bool? isLoading,
    List<KanaLearningState>? reviewList,
    int? currentIndex,
    bool? isFinished,
    String? error,
  }) {
    return KanaReviewState(
      isLoading: isLoading ?? this.isLoading,
      reviewList: reviewList ?? this.reviewList,
      currentIndex: currentIndex ?? this.currentIndex,
      isFinished: isFinished ?? this.isFinished,
      error: error,
    );
  }
}
