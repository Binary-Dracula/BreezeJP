import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/models/article/article.dart';

part 'article_state.freezed.dart';

@freezed
abstract class ArticleState with _$ArticleState {
  const factory ArticleState({
    required Article article,

    @Default(true) bool showFurigana,
    @Default(true) bool showTranslation,

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
