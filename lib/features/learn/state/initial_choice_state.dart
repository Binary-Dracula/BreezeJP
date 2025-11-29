import '../../../data/models/word_choice.dart';

/// 初始选择页状态
class InitialChoiceState {
  /// 5 个随机单词选择项
  final List<WordChoice> choices;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  const InitialChoiceState({
    this.choices = const [],
    this.isLoading = false,
    this.error,
  });

  InitialChoiceState copyWith({
    List<WordChoice>? choices,
    bool? isLoading,
    String? error,
  }) {
    return InitialChoiceState(
      choices: choices ?? this.choices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
