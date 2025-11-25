import '../../../data/models/study_word.dart';
import '../../../data/models/word_detail.dart';

/// 学习页面状态
class LearnState {
  // 学习队列
  final List<StudyWord> studyQueue;
  // 单词详情缓存 (wordId -> WordDetail)
  final Map<int, WordDetail> wordDetails;

  final int currentIndex;
  final bool isLoading;
  final String? error;
  final bool isPlayingWordAudio;
  final bool isPlayingExampleAudio;
  final int? playingExampleIndex;

  // 是否已经加载过数据（区分初始状态和真正的空数据）
  final bool hasLoaded;

  LearnState({
    this.studyQueue = const [],
    this.wordDetails = const {},
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    this.isPlayingWordAudio = false,
    this.isPlayingExampleAudio = false,
    this.playingExampleIndex,
    this.hasLoaded = false,
  });

  /// 当前正在学习的单词进度
  StudyWord? get currentStudyWord =>
      studyQueue.isNotEmpty && currentIndex < studyQueue.length
      ? studyQueue[currentIndex]
      : null;

  /// 当前单词详情
  WordDetail? get currentWordDetail {
    final studyWord = currentStudyWord;
    if (studyWord == null) return null;
    return wordDetails[studyWord.wordId];
  }

  // 兼容旧代码，暂时保留 currentWord getter 指向 currentWordDetail
  WordDetail? get currentWord => currentWordDetail;

  bool get hasNext => currentIndex < studyQueue.length - 1;
  bool get hasPrevious => currentIndex > 0;

  /// 是否为初始状态（还没加载过数据）
  bool get isInitial => !hasLoaded && studyQueue.isEmpty && !isLoading;

  /// 队列是否为空（加载后没有可学习的单词）
  bool get isEmpty => hasLoaded && studyQueue.isEmpty && !isLoading;

  /// 当前批次是否学习完成（已学完所有加载的单词）
  bool get isBatchCompleted =>
      hasLoaded && studyQueue.isNotEmpty && currentIndex >= studyQueue.length;

  /// 学习进度（当前/总数）
  String get progressText => '${currentIndex + 1}/${studyQueue.length}';

  LearnState copyWith({
    List<StudyWord>? studyQueue,
    Map<int, WordDetail>? wordDetails,
    int? currentIndex,
    bool? isLoading,
    String? error,
    bool? isPlayingWordAudio,
    bool? isPlayingExampleAudio,
    int? playingExampleIndex,
    bool? hasLoaded,
  }) {
    return LearnState(
      studyQueue: studyQueue ?? this.studyQueue,
      wordDetails: wordDetails ?? this.wordDetails,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPlayingWordAudio: isPlayingWordAudio ?? this.isPlayingWordAudio,
      isPlayingExampleAudio:
          isPlayingExampleAudio ?? this.isPlayingExampleAudio,
      playingExampleIndex: playingExampleIndex,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}
