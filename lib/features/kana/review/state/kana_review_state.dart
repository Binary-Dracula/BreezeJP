import 'package:flutter/foundation.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';

@immutable
class KanaReviewState {
  final bool isLoading;
  final List<ReviewKanaItem> reviewList;
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

  ReviewKanaItem? get current =>
      (currentIndex >= 0 && currentIndex < reviewList.length)
      ? reviewList[currentIndex]
      : null;

  bool get hasError => error != null;

  KanaReviewState copyWith({
    bool? isLoading,
    List<ReviewKanaItem>? reviewList,
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

/// 读音回忆模式的复习条目
class ReviewKanaItem {
  final KanaLetter kanaLetter;
  final KanaLearningState learningState;
  final String? audioFilename;

  ReviewKanaItem({
    required this.kanaLetter,
    required this.learningState,
    this.audioFilename,
  });
}
