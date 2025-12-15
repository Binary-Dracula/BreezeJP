import 'package:flutter/foundation.dart';
import 'review_kana_item.dart';
import 'matching_pair.dart'; // 若需要 ReviewKanaItem

@immutable
class MatchingState {
  final bool isLoading;

  /// 是否为空复习态（无待复习数据）
  final bool isEmpty;

  /// 当前题型类型：recall / audio / switchMode
  final ReviewQuestionType? currentQuestionType;

  /// 当前组（remaining items）
  final List<ReviewKanaItem> remaining;

  /// 当前屏幕显示的 4 对题目
  final List<MatchingPair> activePairs;

  /// 用户选中的左侧项 index（null 表示未选）
  final int? selectedLeftIndex;

  /// 用户选中的右侧项 index（null 表示未选）
  final int? selectedRightIndex;

  /// 本组是否完成
  final bool isGroupFinished;

  /// 全部复习是否完成
  final bool isAllFinished;

  final String? error;

  const MatchingState({
    this.isLoading = false,
    this.isEmpty = false,
    this.currentQuestionType,
    this.remaining = const [],
    this.activePairs = const [],
    this.selectedLeftIndex,
    this.selectedRightIndex,
    this.isGroupFinished = false,
    this.isAllFinished = false,
    this.error,
  });

  MatchingState copyWith({
    bool? isLoading,
    ReviewQuestionType? currentQuestionType,
    bool resetCurrentQuestionType = false,
    List<ReviewKanaItem>? remaining,
    List<MatchingPair>? activePairs,
    int? selectedLeftIndex,
    int? selectedRightIndex,
    bool? isGroupFinished,
    bool? isAllFinished,
    bool? isEmpty,
    String? error,
  }) {
    return MatchingState(
      isLoading: isLoading ?? this.isLoading,
      currentQuestionType: resetCurrentQuestionType
          ? null
          : (currentQuestionType ?? this.currentQuestionType),
      remaining: remaining ?? this.remaining,
      activePairs: activePairs ?? this.activePairs,
      selectedLeftIndex: selectedLeftIndex,
      selectedRightIndex: selectedRightIndex,
      isGroupFinished: isGroupFinished ?? this.isGroupFinished,
      isAllFinished: isAllFinished ?? this.isAllFinished,
      isEmpty: isEmpty ?? this.isEmpty,
      error: error,
    );
  }
}
