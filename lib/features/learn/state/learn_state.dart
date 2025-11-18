import '../../../data/models/word_detail.dart';

/// 学习状态
class LearnState {
  final bool isLoading;
  final List<WordDetail> words;
  final int currentIndex;
  final String? error;
  final String? jlptLevel;
  final int totalWords;
  final bool isCompleted;

  const LearnState({
    this.isLoading = false,
    this.words = const [],
    this.currentIndex = 0,
    this.error,
    this.jlptLevel,
    this.totalWords = 0,
    this.isCompleted = false,
  });

  LearnState copyWith({
    bool? isLoading,
    List<WordDetail>? words,
    int? currentIndex,
    String? error,
    String? jlptLevel,
    int? totalWords,
    bool? isCompleted,
  }) {
    return LearnState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      error: error,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      totalWords: totalWords ?? this.totalWords,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// 当前单词
  WordDetail? get currentWord => words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  /// 是否有下一个
  bool get hasNext => currentIndex < words.length - 1;

  /// 是否有上一个
  bool get hasPrevious => currentIndex > 0;

  /// 进度百分比
  double get progress => words.isEmpty ? 0 : (currentIndex + 1) / words.length;

  /// 是否有数据
  bool get hasData => words.isNotEmpty;

  /// 是否有错误
  bool get hasError => error != null;
}
