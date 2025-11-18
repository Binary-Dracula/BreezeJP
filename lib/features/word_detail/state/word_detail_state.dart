import '../../../data/models/word_detail.dart';

/// 单词详情状态
class WordDetailState {
  final bool isLoading;
  final WordDetail? detail;
  final String? error;
  final int? wordId;

  const WordDetailState({
    this.isLoading = false,
    this.detail,
    this.error,
    this.wordId,
  });

  WordDetailState copyWith({
    bool? isLoading,
    WordDetail? detail,
    String? error,
    int? wordId,
  }) {
    return WordDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      error: error,
      wordId: wordId ?? this.wordId,
    );
  }

  /// 是否有数据
  bool get hasData => detail != null;

  /// 是否有错误
  bool get hasError => error != null;
}
