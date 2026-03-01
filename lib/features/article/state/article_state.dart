import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/models/article/article.dart';

part 'article_state.freezed.dart';

/// 假名/翻译显示模式（四态轮转）
enum ArticleDisplayMode {
  /// 假名 + 翻译全部显示
  all,

  /// 只显示假名
  furiganaOnly,

  /// 只显示翻译
  translationOnly,

  /// 假名和翻译全部隐藏
  none,
}

@freezed
abstract class ArticleState with _$ArticleState {
  const factory ArticleState({
    required Article article,

    /// 假名/翻译显示模式
    @Default(ArticleDisplayMode.all) ArticleDisplayMode displayMode,

    // 音频播放相关状态
    @Default(false) bool isPlaying,
    @Default(1.0) double currentSpeed,
    @Default(0) int currentPositionMs,

    // 当前高亮的句子 Index
    @Default(-1) int activeIndex,

    // 用户是否打断了自动滚动
    @Default(false) bool userInterruptedScroll,
  }) = _ArticleState;
}
