import '../../../data/models/word.dart';

/// 单词列表状态
class WordListState {
  final bool isLoading;
  final List<Word> words;
  final String? error;
  final String? currentLevel;
  final int totalCount;

  const WordListState({
    this.isLoading = false,
    this.words = const [],
    this.error,
    this.currentLevel,
    this.totalCount = 0,
  });

  WordListState copyWith({
    bool? isLoading,
    List<Word>? words,
    String? error,
    String? currentLevel,
    int? totalCount,
  }) {
    return WordListState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
      error: error,
      currentLevel: currentLevel ?? this.currentLevel,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  /// 是否有数据
  bool get hasData => words.isNotEmpty;

  /// 是否为空
  bool get isEmpty => !isLoading && words.isEmpty;

  /// 是否有错误
  bool get hasError => error != null;
}
