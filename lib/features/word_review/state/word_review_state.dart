import 'package:flutter/foundation.dart';

import 'word_review_item.dart';

class WordReviewPair {
  WordReviewItem item;
  String left;
  String right;
  bool isMatched;

  WordReviewPair({
    required this.item,
    required this.left,
    required this.right,
    this.isMatched = false,
  });
}

class WordReviewOption {
  int pairIndex;
  String value;

  WordReviewOption({required this.pairIndex, required this.value});
}

@immutable
class WordReviewState {
  static const Object _unset = Object();

  final bool isLoading;
  final bool isEmpty;
  final WordReviewQuestionType? currentQuestionType;
  final List<WordReviewPair> activePairs;
  final List<WordReviewItem> remainingItems;
  final List<WordReviewOption> rightOptions;
  final int? selectedLeftIndex;
  final int? selectedRightIndex;
  final bool isGroupFinished;
  final bool isAllFinished;
  final String? error;

  const WordReviewState({
    this.isLoading = false,
    this.isEmpty = false,
    this.currentQuestionType,
    this.activePairs = const [],
    this.remainingItems = const [],
    this.rightOptions = const [],
    this.selectedLeftIndex,
    this.selectedRightIndex,
    this.isGroupFinished = false,
    this.isAllFinished = false,
    this.error,
  });

  WordReviewState copyWith({
    bool? isLoading,
    bool? isEmpty,
    WordReviewQuestionType? currentQuestionType,
    bool resetCurrentQuestionType = false,
    List<WordReviewPair>? activePairs,
    List<WordReviewItem>? remainingItems,
    List<WordReviewOption>? rightOptions,
    Object? selectedLeftIndex = _unset,
    Object? selectedRightIndex = _unset,
    bool? isGroupFinished,
    bool? isAllFinished,
    String? error,
  }) {
    return WordReviewState(
      isLoading: isLoading ?? this.isLoading,
      isEmpty: isEmpty ?? this.isEmpty,
      currentQuestionType: resetCurrentQuestionType
          ? null
          : (currentQuestionType ?? this.currentQuestionType),
      activePairs: activePairs ?? this.activePairs,
      remainingItems: remainingItems ?? this.remainingItems,
      rightOptions: rightOptions ?? this.rightOptions,
      selectedLeftIndex: selectedLeftIndex == _unset
          ? this.selectedLeftIndex
          : selectedLeftIndex as int?,
      selectedRightIndex: selectedRightIndex == _unset
          ? this.selectedRightIndex
          : selectedRightIndex as int?,
      isGroupFinished: isGroupFinished ?? this.isGroupFinished,
      isAllFinished: isAllFinished ?? this.isAllFinished,
      error: error,
    );
  }
}
