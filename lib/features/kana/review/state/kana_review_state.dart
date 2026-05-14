import 'package:flutter/foundation.dart';
import '../../../../core/algorithm/srs_types.dart';
import '../../../word_review/state/word_review_state.dart'; // 复用 ReviewCardPhase
import 'review_kana_item.dart';

@immutable
class KanaReviewAnsweredResult {
  const KanaReviewAnsweredResult({required this.kanaId, required this.rating});

  final int kanaId;
  final ReviewRating rating;

  Map<String, dynamic> toJson() {
    return {'kana_id': kanaId, 'rating': rating.name};
  }

  factory KanaReviewAnsweredResult.fromJson(Map<String, dynamic> json) {
    final ratingValue = (json['rating'] as String?)?.trim();
    final rating = ReviewRating.values.firstWhere(
      (entry) => entry.name == ratingValue,
      orElse: () => ReviewRating.good,
    );

    return KanaReviewAnsweredResult(
      kanaId: (json['kana_id'] as int?) ?? 0,
      rating: rating,
    );
  }
}

@immutable
class KanaReviewState {
  static const Object _unset = Object();

  final String? localSessionId;
  final String? sessionId;
  final DateTime? sessionCreatedAt;
  final bool isLoading;
  final bool isEmpty;
  final List<ReviewKanaItem> initialItems;
  final List<ReviewKanaItem> items;
  final List<KanaReviewAnsweredResult> answeredResults;
  final int currentIndex;
  final ReviewCardPhase currentPhase;
  final bool hasMistakeOnCurrent;
  final List<String> currentOptions;
  final bool isAllFinished;
  final String? error;
  final bool isNetworkError;

  const KanaReviewState({
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
    this.isAllFinished = false,
    this.error,
    this.isNetworkError = false,
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
    Object? localSessionId = _unset,
    Object? sessionId = _unset,
    Object? sessionCreatedAt = _unset,
    bool? isLoading,
    bool? isEmpty,
    List<ReviewKanaItem>? initialItems,
    List<ReviewKanaItem>? items,
    List<KanaReviewAnsweredResult>? answeredResults,
    int? currentIndex,
    ReviewCardPhase? currentPhase,
    bool? hasMistakeOnCurrent,
    List<String>? currentOptions,
    bool? isAllFinished,
    Object? error = _unset,
    bool? isNetworkError,
  }) {
    return KanaReviewState(
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
      isAllFinished: isAllFinished ?? this.isAllFinished,
      error: error == _unset ? this.error : error as String?,
      isNetworkError: isNetworkError ?? this.isNetworkError,
    );
  }
}
