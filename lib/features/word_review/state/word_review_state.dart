import 'package:flutter/foundation.dart';

import '../../../core/algorithm/srs_types.dart';

import 'word_review_item.dart';

enum ReviewCardPhase {
  testing, // 阶段一：客观答题
  grading, // 阶段二：主观评价 (Hard / Good / Easy)
}

@immutable
class WordReviewAnsweredResult {
  const WordReviewAnsweredResult({
    required this.wordId,
    required this.rating,
    this.bookId,
  });

  final String wordId;
  final String? bookId;
  final ReviewRating rating;

  Map<String, dynamic> toJson() {
    return {
      'word_id': wordId,
      if (bookId != null) 'book_id': bookId,
      'rating': rating.name,
    };
  }

  factory WordReviewAnsweredResult.fromJson(Map<String, dynamic> json) {
    final ratingValue = (json['rating'] as String?)?.trim();
    final rating = ReviewRating.values.firstWhere(
      (entry) => entry.name == ratingValue,
      orElse: () => ReviewRating.good,
    );

    return WordReviewAnsweredResult(
      wordId: (json['word_id'] as String?) ?? '',
      bookId: json['book_id'] as String?,
      rating: rating,
    );
  }
}

@immutable
class WordReviewState {
  static const Object _unset = Object();

  final String? localSessionId;
  final String? sessionId;
  final DateTime? sessionCreatedAt;
  final bool isLoading;
  final bool isEmpty;

  // 复习队列与进度
  final List<WordReviewItem> initialItems;
  final List<WordReviewItem> items;
  final List<WordReviewAnsweredResult> answeredResults;
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
    this.localSessionId,
    this.sessionId,
    this.sessionCreatedAt,
    this.isLoading = false,
    this.isEmpty = false,
    this.initialItems = const [],
    this.items = const [],
    this.answeredResults = const [],
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
    Object? localSessionId = _unset,
    Object? sessionId = _unset,
    Object? sessionCreatedAt = _unset,
    bool? isLoading,
    bool? isEmpty,
    List<WordReviewItem>? initialItems,
    List<WordReviewItem>? items,
    List<WordReviewAnsweredResult>? answeredResults,
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
      localSessionId: localSessionId == _unset
          ? this.localSessionId
          : (localSessionId as String?),
      sessionId: sessionId == _unset ? this.sessionId : (sessionId as String?),
      sessionCreatedAt: sessionCreatedAt == _unset
          ? this.sessionCreatedAt
          : (sessionCreatedAt as DateTime?),
      isLoading: isLoading ?? this.isLoading,
      isEmpty: isEmpty ?? this.isEmpty,
      initialItems: initialItems ?? this.initialItems,
      items: items ?? this.items,
      answeredResults: answeredResults ?? this.answeredResults,
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
