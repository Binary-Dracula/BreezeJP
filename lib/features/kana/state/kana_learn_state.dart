import '../../../data/models/kana_detail.dart';
import '../../../data/models/kana_letter.dart';

/// 五十音学习页面状态
class KanaLearnState {
  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 当前学习的假名详情
  final KanaDetail? currentKanaDetail;

  /// 学习队列
  final List<KanaLetter> studyQueue;

  /// 当前索引
  final int currentIndex;

  /// 已学习的假名 ID 集合
  final Set<int> learnedKanaIds;

  /// 是否显示罗马音
  final bool showRomaji;

  /// 是否显示助记词
  final bool showMnemonic;

  const KanaLearnState({
    this.isLoading = false,
    this.error,
    this.currentKanaDetail,
    this.studyQueue = const [],
    this.currentIndex = 0,
    this.learnedKanaIds = const {},
    this.showRomaji = true,
    this.showMnemonic = true,
  });

  /// 是否有错误
  bool get hasError => error != null;

  /// 当前假名
  KanaLetter? get currentKana =>
      currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;

  /// 已学习数量
  int get learnedCount => learnedKanaIds.length;

  /// 是否在队列末尾
  bool get isAtQueueEnd => currentIndex >= studyQueue.length - 1;

  /// 队列是否为空
  bool get isEmpty => studyQueue.isEmpty;

  /// 当前进度 (1-based)
  int get currentProgress => currentIndex + 1;

  /// 总数
  int get totalCount => studyQueue.length;

  KanaLearnState copyWith({
    bool? isLoading,
    String? error,
    KanaDetail? currentKanaDetail,
    List<KanaLetter>? studyQueue,
    int? currentIndex,
    Set<int>? learnedKanaIds,
    bool? showRomaji,
    bool? showMnemonic,
  }) {
    return KanaLearnState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentKanaDetail: currentKanaDetail ?? this.currentKanaDetail,
      studyQueue: studyQueue ?? this.studyQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      learnedKanaIds: learnedKanaIds ?? this.learnedKanaIds,
      showRomaji: showRomaji ?? this.showRomaji,
      showMnemonic: showMnemonic ?? this.showMnemonic,
    );
  }
}
