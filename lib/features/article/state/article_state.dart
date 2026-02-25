import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/models/article/article.dart';

part 'article_state.freezed.dart';

@freezed
abstract class ArticleState with _$ArticleState {
  const factory ArticleState({
    required Article article,

    @Default(true) bool showFurigana,
    @Default(true) bool showTranslation,

    // 听力/循环相关状态
    @Default(false) bool isPlaying,
    @Default(1.0) double currentSpeed,
    @Default(0) int currentPositionMs,

    // 当前高亮的句子 Index
    @Default(-1) int activeIndex,

    // 用户是否打断了自动循环/滚动 (UserScrollNotification 滑动列表)
    @Default(false) bool userInterruptedScroll,

    // 是否正在录音
    @Default(false) bool isRecording,
    @Default(0) int recordedDurationMs,
  }) = _ArticleState;
}
