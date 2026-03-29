import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/models/article/article_detail.dart';

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

/// 文章交互模式：普通听读、AB 循环听
enum ArticleMode { normal, abLoop }

@freezed
abstract class ArticleState with _$ArticleState {
  const factory ArticleState({
    required ArticleDetail article,

    /// 假名/翻译显示模式
    @Default(ArticleDisplayMode.all) ArticleDisplayMode displayMode,

    /// 当前的交互模式
    @Default(ArticleMode.normal) ArticleMode currentMode,

    // 音频播放相关状态
    @Default(false) bool isPlaying,
    @Default(1.0) double currentSpeed,
    @Default(0) int currentPositionMs,

    // 当前高亮的句子 Index
    @Default(-1) int activeIndex,

    // 用户是否打断了自动滚动
    @Default(false) bool userInterruptedScroll,

    // --- AB 循环听相关状态 ---
    int? loopStartIdx, // A 句索引
    int? loopEndIdx, // B 句索引
    @Default(3) int targetLoopCount, // 目标循环次数 (默认 3 次)
    @Default(0) int currentLoopCount, // 当前已完成循环次数
  }) = _ArticleState;
}
