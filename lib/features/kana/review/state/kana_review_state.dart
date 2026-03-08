import 'package:flutter/foundation.dart';
import '../../../word_review/state/word_review_state.dart'; // 复用 ReviewCardPhase
import 'review_kana_item.dart';

@immutable
class KanaReviewState {
  static const Object _unset = Object();

  final bool isLoading;
  final bool isEmpty;
  final List<ReviewKanaItem> items;
  final int currentIndex;
  final ReviewCardPhase currentPhase;
  final bool hasMistakeOnCurrent;
  final List<String> currentOptions;
  final bool isAllFinished;
  final String? error;

  const KanaReviewState({
    this.isLoading = false,
    this.isEmpty = false,
    this.items = const [],
    this.currentIndex = 0,
    this.currentPhase = ReviewCardPhase.testing,
    this.hasMistakeOnCurrent = false,
    this.currentOptions = const [],
    this.isAllFinished = false,
    this.error,
  });

  ReviewKanaItem? get currentItem {
    if (currentIndex >= 0 && currentIndex < items.length) {
      return items[currentIndex];
    }
    return null;
  }

  double get progress {
    if (items.isEmpty) return 0;
    return (currentIndex) / items.length;
  }

  KanaReviewState copyWith({
    bool? isLoading,
    bool? isEmpty,
    List<ReviewKanaItem>? items,
    int? currentIndex,
    ReviewCardPhase? currentPhase,
    bool? hasMistakeOnCurrent,
    List<String>? currentOptions,
    bool? isAllFinished,
    Object? error = _unset,
  }) {
    return KanaReviewState(
      isLoading: isLoading ?? this.isLoading,
      isEmpty: isEmpty ?? this.isEmpty,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      currentPhase: currentPhase ?? this.currentPhase,
      hasMistakeOnCurrent: hasMistakeOnCurrent ?? this.hasMistakeOnCurrent,
      currentOptions: currentOptions ?? this.currentOptions,
      isAllFinished: isAllFinished ?? this.isAllFinished,
      error: error == _unset ? this.error : error as String?,
    );
  }
}
