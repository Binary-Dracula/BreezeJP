import 'package:flutter/foundation.dart';

import 'word_review_item.dart';

enum ReviewCardPhase {
  testing, // 阶段一：客观答题
  grading, // 阶段二：主观评价 (Hard / Good / Easy)
}

@immutable
class WordReviewState {
  static const Object _unset = Object();

  final String? sessionId;
  final bool isLoading;
  final bool isEmpty;

  // 复习队列与进度
  final List<WordReviewItem> items;
  final int currentIndex;

  // 当前卡片的状态
  final ReviewCardPhase currentPhase;
  final bool hasMistakeOnCurrent; // 客观题是否已经答错过（决定该题打入 Again）

  // 客观题的备选项 (由于要支持不同的题型，这里做一层通用抽象：文字选项)
  // 如果是复杂的题型，可能需要具体页面去获取，但这里为了快速改造，我们保留通用的 option list
  final List<String> currentOptions;

  /// 当前卡片答题开始时间（用于自动计算评分）
  final DateTime? cardStartTime;

  final bool isAllFinished;
  final String? error;
  final bool isNetworkError;

  const WordReviewState({
    this.sessionId,
    this.isLoading = false,
    this.isEmpty = false,
    this.items = const [],
    this.currentIndex = 0,
    this.currentPhase = ReviewCardPhase.testing,
    this.hasMistakeOnCurrent = false,
    this.currentOptions = const [],
    this.cardStartTime,
    this.isAllFinished = false,
    this.error,
    this.isNetworkError = false,
  });

  WordReviewItem? get currentItem {
    if (items.isEmpty || currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  double get progress {
    if (items.isEmpty) return 1.0;
    return currentIndex / items.length;
  }

  WordReviewState copyWith({
    Object? sessionId = _unset,
    bool? isLoading,
    bool? isEmpty,
    List<WordReviewItem>? items,
    int? currentIndex,
    ReviewCardPhase? currentPhase,
    bool? hasMistakeOnCurrent,
    List<String>? currentOptions,
    Object? cardStartTime = _unset,
    bool? isAllFinished,
    Object? error = _unset,
    bool? isNetworkError,
  }) {
    return WordReviewState(
      sessionId: sessionId == _unset ? this.sessionId : (sessionId as String?),
      isLoading: isLoading ?? this.isLoading,
      isEmpty: isEmpty ?? this.isEmpty,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      currentPhase: currentPhase ?? this.currentPhase,
      hasMistakeOnCurrent: hasMistakeOnCurrent ?? this.hasMistakeOnCurrent,
      currentOptions: currentOptions ?? this.currentOptions,
      cardStartTime: cardStartTime == _unset
          ? this.cardStartTime
          : (cardStartTime as DateTime?),
      isAllFinished: isAllFinished ?? this.isAllFinished,
      error: error == _unset ? this.error : (error as String?),
      isNetworkError: isNetworkError ?? this.isNetworkError,
    );
  }
}
