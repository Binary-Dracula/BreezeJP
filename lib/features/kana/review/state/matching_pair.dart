import 'kana_review_state.dart';

class MatchingPair {
  final ReviewKanaItem item;

  /// 左侧内容（文字 or 喇叭 icon id）
  final String left;

  /// 正确右项
  final String rightCorrect;

  /// 右侧候选项（包含正确项 + 干扰项）
  final List<String> rightOptions;

  MatchingPair({
    required this.item,
    required this.left,
    required this.rightCorrect,
    required this.rightOptions,
  });
}
