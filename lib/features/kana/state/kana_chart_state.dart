import '../../../data/models/kana_detail.dart';

/// 五十音表页面状态
class KanaChartState {
  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 所有假名（带学习状态）
  final List<KanaLetterWithState> kanaLetters;

  /// 所有类型列表（从数据库获取）
  final List<String> kanaTypes;

  /// 当前选中的类型筛选 (null=全部)
  final String? selectedType;

  /// 当前显示模式 (hiragana/katakana)
  final KanaDisplayMode displayMode;

  /// 学习统计
  final int totalCount;
  final int learnedCount;

  const KanaChartState({
    this.isLoading = false,
    this.error,
    this.kanaLetters = const [],
    this.kanaTypes = const [],
    this.selectedType,
    this.displayMode = KanaDisplayMode.hiragana,
    this.totalCount = 0,
    this.learnedCount = 0,
  });

  /// 是否有错误
  bool get hasError => error != null;

  /// 学习进度百分比
  double get progressPercent =>
      totalCount > 0 ? learnedCount / totalCount : 0.0;

  /// 剩余未学习数
  int get remainingCount => totalCount - learnedCount;

  /// 根据当前筛选获取假名列表
  List<KanaLetterWithState> get filteredKanaLetters {
    if (selectedType == null) return kanaLetters;
    return kanaLetters.where((k) => k.letter.type == selectedType).toList();
  }

  /// 按行分组的假名
  Map<String, List<KanaLetterWithState>> get groupedKanaLetters {
    final grouped = <String, List<KanaLetterWithState>>{};
    for (final kana in filteredKanaLetters) {
      final group = kana.letter.kanaGroup ?? '其他';
      grouped.putIfAbsent(group, () => []).add(kana);
    }
    return grouped;
  }

  KanaChartState copyWith({
    bool? isLoading,
    String? error,
    List<KanaLetterWithState>? kanaLetters,
    List<String>? kanaTypes,
    String? selectedType,
    KanaDisplayMode? displayMode,
    int? totalCount,
    int? learnedCount,
  }) {
    return KanaChartState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      kanaLetters: kanaLetters ?? this.kanaLetters,
      kanaTypes: kanaTypes ?? this.kanaTypes,
      selectedType: selectedType,
      displayMode: displayMode ?? this.displayMode,
      totalCount: totalCount ?? this.totalCount,
      learnedCount: learnedCount ?? this.learnedCount,
    );
  }
}

/// 假名显示模式
enum KanaDisplayMode {
  hiragana, // 平假名
  katakana, // 片假名
}
