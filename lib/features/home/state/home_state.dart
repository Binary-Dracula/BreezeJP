/// 主页状态
class HomeState {
  final bool isLoading;
  final String? error;

  // 用户信息
  final String userName;

  // 核心卡片数据
  final int reviewCount;

  // 待复习五十音数量
  final int kanaReviewCount;

  // 学习统计
  final int masteredWordCount;

  final bool isInitialized;

  const HomeState({
    this.isLoading = false,
    this.error,
    this.userName = 'BreezeJP User',
    this.reviewCount = 0,
    this.kanaReviewCount = 0,
    this.masteredWordCount = 0,
    this.isInitialized = false,
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    String? userName,
    int? reviewCount,
    int? kanaReviewCount,
    int? masteredWordCount,
    bool? isInitialized,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userName: userName ?? this.userName,
      reviewCount: reviewCount ?? this.reviewCount,
      kanaReviewCount: kanaReviewCount ?? this.kanaReviewCount,
      masteredWordCount: masteredWordCount ?? this.masteredWordCount,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// 是否有任务 (待复习或新单词)
  bool get hasTask => reviewCount > 0 || kanaReviewCount > 0;

  /// 是否有错误
  bool get hasError => error != null;

  /// 是否已初始化数据
  bool get hasData => isInitialized;
}
