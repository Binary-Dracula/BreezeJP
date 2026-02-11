import '../../../core/constants/learning_status.dart';
import '../../../data/models/read/vocabulary_book_item.dart';

/// 单词本页面状态（不可变）
class VocabularyBookState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreLearning;
  final bool hasMoreMastered;
  final String? error;

  final List<VocabularyBookItem> learningWords;
  final List<VocabularyBookItem> masteredWords;

  final int learningCount;
  final int masteredCount;

  final String searchQuery;
  final int currentTabIndex; // 0=学习中, 1=已掌握

  const VocabularyBookState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreLearning = true,
    this.hasMoreMastered = true,
    this.error,
    this.learningWords = const [],
    this.masteredWords = const [],
    this.learningCount = 0,
    this.masteredCount = 0,
    this.searchQuery = '',
    this.currentTabIndex = 0,
  });

  VocabularyBookState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreLearning,
    bool? hasMoreMastered,
    String? error,
    List<VocabularyBookItem>? learningWords,
    List<VocabularyBookItem>? masteredWords,
    int? learningCount,
    int? masteredCount,
    String? searchQuery,
    int? currentTabIndex,
  }) {
    return VocabularyBookState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreLearning: hasMoreLearning ?? this.hasMoreLearning,
      hasMoreMastered: hasMoreMastered ?? this.hasMoreMastered,
      error: error,
      learningWords: learningWords ?? this.learningWords,
      masteredWords: masteredWords ?? this.masteredWords,
      learningCount: learningCount ?? this.learningCount,
      masteredCount: masteredCount ?? this.masteredCount,
      searchQuery: searchQuery ?? this.searchQuery,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
    );
  }

  /// 当前 Tab 对应的列表
  List<VocabularyBookItem> get currentList =>
      currentTabIndex == 0 ? learningWords : masteredWords;

  /// 当前 Tab 是否还有更多数据
  bool get currentHasMore =>
      currentTabIndex == 0 ? hasMoreLearning : hasMoreMastered;

  /// 当前 Tab 对应的状态
  LearningStatus get currentStatus =>
      currentTabIndex == 0 ? LearningStatus.learning : LearningStatus.mastered;

  /// 是否为空（当前 Tab 无数据）
  bool get isEmpty => currentList.isEmpty && !isLoading;
}
