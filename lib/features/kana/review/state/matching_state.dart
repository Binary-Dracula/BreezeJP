import 'package:flutter/foundation.dart';
import 'review_kana_item.dart';

class MatchingPair {
  ReviewKanaItem item;
  String left;
  String right;
  bool isMatched;

  MatchingPair({
    required this.item,
    required this.left,
    required this.right,
    this.isMatched = false,
  });
}

class RightOption {
  int pairIndex;
  String value;

  RightOption({required this.pairIndex, required this.value});
}

@immutable
class MatchingState {
  static const Object _unset = Object();

  final bool isLoading;

  /// 是否为空复习态（无待复习数据）
  final bool isEmpty;

  /// 当前题型类型：recall / audio / switchMode
  final ReviewQuestionType? currentQuestionType;

  /// 当前屏幕展示的一一对应配对（最多 4×4 Pair Window）
  ///
  /// - activePairs.length <= 4
  /// - 当 remainingItems 为空时，通过 isMatched 标记完成情况
  final List<MatchingPair> activePairs;

  /// 当前组剩余未上屏的条目
  final List<ReviewKanaItem> remainingItems;

  /// 右侧选项（乱序展示，但仍一一对应 activePairs）
  ///
  /// - rightOptions.length 与 activePairs.length 一致
  /// - 通过 RightOption.pairIndex 指向 activePairs
  final List<RightOption> rightOptions;

  /// 用户选中的左侧 index（null 表示未选/已重置）
  final int? selectedLeftIndex;

  /// 用户选中的右侧项 index（null 表示未选/已重置）
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
    this.activePairs = const [],
    this.remainingItems = const [],
    this.rightOptions = const [],
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
    List<MatchingPair>? activePairs,
    List<ReviewKanaItem>? remainingItems,
    List<RightOption>? rightOptions,
    Object? selectedLeftIndex = _unset,
    Object? selectedRightIndex = _unset,
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
      isEmpty: isEmpty ?? this.isEmpty,
      error: error,
    );
  }
}
