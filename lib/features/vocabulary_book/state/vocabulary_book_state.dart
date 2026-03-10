import '../../../core/constants/learning_status.dart';
import '../../../data/models/read/vocabulary_book_item.dart';

/// 单词本页面状态（不可变）
class VocabularyBookState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreLearning;
  final bool hasMoreMastered;
  final bool hasMoreIgnored;
  final String? error;

  final List<VocabularyBookItem> learningWords;
  final List<VocabularyBookItem> masteredWords;
  final List<VocabularyBookItem> ignoredWords;

  final int learningCount;
  final int masteredCount;
  final int ignoredCount;

  final String searchQuery;
  final int currentTabIndex; // 0=学习中, 1=已掌握, 2=已忽略

  const VocabularyBookState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreLearning = true,
    this.hasMoreMastered = true,
    this.hasMoreIgnored = true,
    this.error,
    this.learningWords = const [],
    this.masteredWords = const [],
    this.ignoredWords = const [],
    this.learningCount = 0,
    this.masteredCount = 0,
    this.ignoredCount = 0,
    this.searchQuery = '',
    this.currentTabIndex = 0,
  });

  VocabularyBookState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreLearning,
    bool? hasMoreMastered,
    bool? hasMoreIgnored,
    String? error,
    List<VocabularyBookItem>? learningWords,
    List<VocabularyBookItem>? masteredWords,
    List<VocabularyBookItem>? ignoredWords,
    int? learningCount,
    int? masteredCount,
    int? ignoredCount,
    String? searchQuery,
    int? currentTabIndex,
  }) {
    return VocabularyBookState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreLearning: hasMoreLearning ?? this.hasMoreLearning,
      hasMoreMastered: hasMoreMastered ?? this.hasMoreMastered,
      hasMoreIgnored: hasMoreIgnored ?? this.hasMoreIgnored,
      error: error,
      learningWords: learningWords ?? this.learningWords,
      masteredWords: masteredWords ?? this.masteredWords,
      ignoredWords: ignoredWords ?? this.ignoredWords,
      learningCount: learningCount ?? this.learningCount,
      masteredCount: masteredCount ?? this.masteredCount,
      ignoredCount: ignoredCount ?? this.ignoredCount,
      searchQuery: searchQuery ?? this.searchQuery,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
    );
  }

  /// 当前 Tab 对应的列表
  List<VocabularyBookItem> get currentList => switch (currentTabIndex) {
    0 => learningWords,
    1 => masteredWords,
    2 => ignoredWords,
    _ => learningWords,
  };

  /// 当前 Tab 是否还有更多数据
  bool get currentHasMore => switch (currentTabIndex) {
    0 => hasMoreLearning,
    1 => hasMoreMastered,
    2 => hasMoreIgnored,
    _ => hasMoreLearning,
  };

  /// 当前 Tab 对应的状态
  LearningStatus get currentStatus => switch (currentTabIndex) {
    0 => LearningStatus.learning,
    1 => LearningStatus.mastered,
    2 => LearningStatus.ignored,
    _ => LearningStatus.learning,
  };

  /// 是否为空（当前 Tab 无数据）
  bool get isEmpty => currentList.isEmpty && !isLoading;
}
