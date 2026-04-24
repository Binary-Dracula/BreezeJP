import '../../../data/models/word_detail.dart';

class WordDetailState {
  final bool isLoading;
  final WordDetail? detail;
  final String? error;

  const WordDetailState({
    this.isLoading = false,
    this.detail,
    this.error,
  });

  static const _unset = Object();

  WordDetailState copyWith({
    bool? isLoading,
    Object? detail = _unset,
    Object? error = _unset,
  }) {
    return WordDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail == _unset ? this.detail : detail as WordDetail?,
      error: error == _unset ? this.error : error as String?,
    );
  }
}