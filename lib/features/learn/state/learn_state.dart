import '../../../core/constants/learning_status.dart';
import '../../../data/models/word_detail.dart';

/// 卡片翻页动画方向
enum SlideDirection { next, prev }

/// 学习页状态（2.0 — 批次式学习，翻到即标记 learned）
class LearnState {
  /// 当前批次的单词列表
  final List<WordDetail> words;

  /// 当前卡片索引（0-based）
  final int currentIndex;

  /// 当前学习的书籍 ID
  final String? bookId;

  /// 每张卡片的状态覆盖（用户显式标记 mastered/ignored）
  final Map<int, LearningStatus> wordStates;

  /// 翻页动画方向
  final SlideDirection slideDirection;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 当前批次是否已完成（可触发跳转到批次结束页）
  final bool isBatchComplete;

  /// 是否书籍内所有词已学完
  final bool isBookComplete;

  /// 是否是断点恢复（用于提示）
  final bool isResumed;

  /// 当前辞书不可再继续拉取下一批新词
  final bool isBookUnavailableForNextBatch;

  /// 当前书总词数（来自 API）
  final int totalWordsInBook;

  /// 批次内每张卡对应的 book_sort_order（与 words 等长，用于逐卡推进游标）
  final List<int> wordSortOrders;

  const LearnState({
    this.words = const [],
    this.currentIndex = 0,
    this.bookId,
    this.wordStates = const {},
    this.slideDirection = SlideDirection.next,
    this.isLoading = false,
    this.error,
    this.isBatchComplete = false,
    this.isBookComplete = false,
    this.isResumed = false,
    this.isBookUnavailableForNextBatch = false,
    this.totalWordsInBook = 0,
    this.wordSortOrders = const [],
  });

  /// 当前卡片的单词详情
  WordDetail? get currentWordDetail =>
      currentIndex < words.length ? words[currentIndex] : null;

  /// 当前卡片的学习状态（用户标记优先，否则为 word.userState）
  LearningStatus currentWordState([int? index]) {
    final i = index ?? currentIndex;
    if (wordStates.containsKey(i)) return wordStates[i]!;
    if (i < words.length) return words[i].userState;
    return LearningStatus.learning;
  }

  /// 是否在最后一张卡片
  bool get isAtLastCard => words.isNotEmpty && currentIndex >= words.length - 1;

  bool get isEmpty => words.isEmpty;

  LearnState copyWith({
    List<WordDetail>? words,
    int? currentIndex,
    String? bookId,
    Map<int, LearningStatus>? wordStates,
    SlideDirection? slideDirection,
    bool? isLoading,
    Object? error = _sentinel,
    bool? isBatchComplete,
    bool? isBookComplete,
    bool? isResumed,
    bool? isBookUnavailableForNextBatch,
    int? totalWordsInBook,
    List<int>? wordSortOrders,
  }) {
    return LearnState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      bookId: bookId ?? this.bookId,
      wordStates: wordStates ?? this.wordStates,
      slideDirection: slideDirection ?? this.slideDirection,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      isBatchComplete: isBatchComplete ?? this.isBatchComplete,
      isBookComplete: isBookComplete ?? this.isBookComplete,
      isResumed: isResumed ?? this.isResumed,
      isBookUnavailableForNextBatch:
          isBookUnavailableForNextBatch ?? this.isBookUnavailableForNextBatch,
      totalWordsInBook: totalWordsInBook ?? this.totalWordsInBook,
      wordSortOrders: wordSortOrders ?? this.wordSortOrders,
    );
  }

  static const Object _sentinel = Object();
}
