import '../../../core/constants/learning_status.dart';
import '../../../data/models/read/grammar_book_item.dart';

/// 语法本页面状态（不可变）
class GrammarBookState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreLearning;
  final bool hasMoreMastered;
  final String? error;

  final List<GrammarBookItem> learningGrammars;
  final List<GrammarBookItem> masteredGrammars;

  final int learningCount;
  final int masteredCount;

  final String searchQuery;
  final int currentTabIndex; // 0=学习中, 1=已掌握

  const GrammarBookState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreLearning = true,
    this.hasMoreMastered = true,
    this.error,
    this.learningGrammars = const [],
    this.masteredGrammars = const [],
    this.learningCount = 0,
    this.masteredCount = 0,
    this.searchQuery = '',
    this.currentTabIndex = 0,
  });

  GrammarBookState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreLearning,
    bool? hasMoreMastered,
    String? error,
    List<GrammarBookItem>? learningGrammars,
    List<GrammarBookItem>? masteredGrammars,
    int? learningCount,
    int? masteredCount,
    String? searchQuery,
    int? currentTabIndex,
  }) {
    return GrammarBookState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreLearning: hasMoreLearning ?? this.hasMoreLearning,
      hasMoreMastered: hasMoreMastered ?? this.hasMoreMastered,
      error: error,
      learningGrammars: learningGrammars ?? this.learningGrammars,
      masteredGrammars: masteredGrammars ?? this.masteredGrammars,
      learningCount: learningCount ?? this.learningCount,
      masteredCount: masteredCount ?? this.masteredCount,
      searchQuery: searchQuery ?? this.searchQuery,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
    );
  }

  /// 当前 Tab 对应的列表
  List<GrammarBookItem> get currentList =>
      currentTabIndex == 0 ? learningGrammars : masteredGrammars;

  /// 当前 Tab 是否还有更多数据
  bool get currentHasMore =>
      currentTabIndex == 0 ? hasMoreLearning : hasMoreMastered;

  /// 当前 Tab 对应的状态
  LearningStatus get currentStatus =>
      currentTabIndex == 0 ? LearningStatus.learning : LearningStatus.mastered;

  /// 是否为空（当前 Tab 无数据）
  bool get isEmpty => currentList.isEmpty && !isLoading;
}
