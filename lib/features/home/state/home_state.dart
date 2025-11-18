/// 主页状态
class HomeState {
  final bool isLoading;
  final Map<String, int> wordCountByLevel;
  final int totalWords;
  final String? error;

  const HomeState({
    this.isLoading = false,
    this.wordCountByLevel = const {},
    this.totalWords = 0,
    this.error,
  });

  HomeState copyWith({
    bool? isLoading,
    Map<String, int>? wordCountByLevel,
    int? totalWords,
    String? error,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      wordCountByLevel: wordCountByLevel ?? this.wordCountByLevel,
      totalWords: totalWords ?? this.totalWords,
      error: error,
    );
  }

  /// 是否有数据
  bool get hasData => wordCountByLevel.isNotEmpty;

  /// 是否有错误
  bool get hasError => error != null;

  /// 获取指定等级的单词数量
  int getCountForLevel(String level) => wordCountByLevel[level] ?? 0;
}
