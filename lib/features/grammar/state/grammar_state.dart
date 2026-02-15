import '../../../data/models/grammar_detail.dart';

/// 语法学习页状态
class GrammarState {
  /// 学习队列
  final List<GrammarDetail> studyQueue;

  /// 当前索引
  final int currentIndex;

  /// 是否正在加载
  final bool isLoading;

  /// 是否正在加载更多
  final bool isLoadingMore;

  /// 错误信息
  final String? error;

  const GrammarState({
    this.studyQueue = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  /// 当前语法详情
  GrammarDetail? get currentGrammarDetail =>
      currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;

  /// 是否在队列末尾
  bool get isAtQueueEnd => currentIndex >= studyQueue.length - 1;

  /// 队列是否为空
  bool get isEmpty => studyQueue.isEmpty;

  GrammarState copyWith({
    List<GrammarDetail>? studyQueue,
    int? currentIndex,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return GrammarState(
      studyQueue: studyQueue ?? this.studyQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}
