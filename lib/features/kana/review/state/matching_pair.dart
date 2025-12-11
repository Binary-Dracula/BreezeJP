import 'kana_review_state.dart';

class MatchingPair {
  final ReviewKanaItem item;

  /// 左侧内容（文字 or 喇叭 icon id）
  final String left;

  /// 正确右项
  final String rightCorrect;

  /// 右侧候选项（包含正确项 + 干扰项）
  final List<String> rightOptions;

  /// 本次复习的错误次数
  final int wrongCount;

  /// 本次复习的尝试次数
  final int attemptCount;

  MatchingPair({
    required this.item,
    required this.left,
    required this.rightCorrect,
    required this.rightOptions,
    this.wrongCount = 0,
    this.attemptCount = 0,
  });

  MatchingPair copyWith({
    int? wrongCount,
    int? attemptCount,
  }) {
    return MatchingPair(
      item: item,
      left: left,
      rightCorrect: rightCorrect,
      rightOptions: rightOptions,
      wrongCount: wrongCount ?? this.wrongCount,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}
