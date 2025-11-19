import '../../../data/models/word_detail.dart';

/// 学习页面状态
class LearnState {
  final List<WordDetail> words;
  final int currentIndex;
  final bool isLoading;
  final String? error;
  final bool isPlayingWordAudio;
  final bool isPlayingExampleAudio;
  final int? playingExampleIndex;

  LearnState({
    this.words = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    this.isPlayingWordAudio = false,
    this.isPlayingExampleAudio = false,
    this.playingExampleIndex,
  });

  WordDetail? get currentWord => words.isNotEmpty && currentIndex < words.length
      ? words[currentIndex]
      : null;

  bool get hasNext => currentIndex < words.length - 1;
  bool get hasPrevious => currentIndex > 0;

  LearnState copyWith({
    List<WordDetail>? words,
    int? currentIndex,
    bool? isLoading,
    String? error,
    bool? isPlayingWordAudio,
    bool? isPlayingExampleAudio,
    int? playingExampleIndex,
  }) {
    return LearnState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPlayingWordAudio: isPlayingWordAudio ?? this.isPlayingWordAudio,
      isPlayingExampleAudio:
          isPlayingExampleAudio ?? this.isPlayingExampleAudio,
      playingExampleIndex: playingExampleIndex,
    );
  }
}
