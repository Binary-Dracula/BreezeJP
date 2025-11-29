import '../../../data/models/word_detail.dart';

/// 学习页状态
class LearnState {
  /// 学习队列
  final List<WordDetail> studyQueue;

  /// 当前索引
  final int currentIndex;

  /// 已学习单词 ID 集合
  final Set<int> learnedWordIds;

  /// 是否正在加载
  final bool isLoading;

  /// 是否正在加载更多关联词
  final bool isLoadingMore;

  /// 路径是否结束（没有更多关联词）
  final bool pathEnded;

  /// 错误信息
  final String? error;

  const LearnState({
    this.studyQueue = const [],
    this.currentIndex = 0,
    this.learnedWordIds = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.pathEnded = false,
    this.error,
  });

  /// 当前单词详情
  WordDetail? get currentWordDetail =>
      currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;

  /// 已学单词数
  int get learnedCount => learnedWordIds.length;

  /// 是否在队列末尾
  bool get isAtQueueEnd => currentIndex >= studyQueue.length - 1;

  /// 队列是否为空
  bool get isEmpty => studyQueue.isEmpty;

  LearnState copyWith({
    List<WordDetail>? studyQueue,
    int? currentIndex,
    Set<int>? learnedWordIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? pathEnded,
    String? error,
  }) {
    return LearnState(
      studyQueue: studyQueue ?? this.studyQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      learnedWordIds: learnedWordIds ?? this.learnedWordIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pathEnded: pathEnded ?? this.pathEnded,
      error: error,
    );
  }
}
