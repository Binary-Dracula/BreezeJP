/// 主页状态
class HomeState {
  final bool isLoading;
  final String? error;

  // 用户信息
  final String userName;

  // 核心卡片数据
  final int reviewCount;
  final int newWordCount;

  // 每日统计数据
  final int streakDays;
  final int masteredWordCount;
  final int todayStudyDurationMinutes;

  final bool isInitialized;

  const HomeState({
    this.isLoading = false,
    this.error,
    this.userName = 'BreezeJP User',
    this.reviewCount = 0,
    this.newWordCount = 0,
    this.streakDays = 0,
    this.masteredWordCount = 0,
    this.todayStudyDurationMinutes = 0,
    this.isInitialized = false,
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    String? userName,
    int? reviewCount,
    int? newWordCount,
    int? streakDays,
    int? masteredWordCount,
    int? todayStudyDurationMinutes,
    bool? isInitialized,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userName: userName ?? this.userName,
      reviewCount: reviewCount ?? this.reviewCount,
      newWordCount: newWordCount ?? this.newWordCount,
      streakDays: streakDays ?? this.streakDays,
      masteredWordCount: masteredWordCount ?? this.masteredWordCount,
      todayStudyDurationMinutes:
          todayStudyDurationMinutes ?? this.todayStudyDurationMinutes,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// 是否有任务 (待复习或新单词)
  bool get hasTask => reviewCount > 0 || newWordCount > 0;

  /// 是否有错误
  bool get hasError => error != null;

  /// 是否已初始化数据
  bool get hasData => isInitialized;
}
