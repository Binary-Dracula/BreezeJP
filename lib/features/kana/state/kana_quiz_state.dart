import '../../../data/models/kana_letter.dart';

/// 五十音测验页面状态
/// 管理题目、进度、答题结果等数据
class KanaQuizState {
  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 测验题目队列
  final List<KanaQuizQuestion> questions;

  /// 当前题目索引
  final int currentIndex;

  /// 已回答的题目结果
  final List<KanaQuizResult> results;

  /// 测验模式
  final KanaQuizMode quizMode;

  /// 测验范围
  final KanaQuizScope quizScope;

  /// 是否已完成测验
  final bool isCompleted;

  /// 当前题目是否已回答
  final bool hasAnswered;

  /// 当前选中的答案索引
  final int? selectedAnswerIndex;

  const KanaQuizState({
    this.isLoading = false,
    this.error,
    this.questions = const [],
    this.currentIndex = 0,
    this.results = const [],
    this.quizMode = KanaQuizMode.kanaToRomaji,
    this.quizScope = KanaQuizScope.learned,
    this.isCompleted = false,
    this.hasAnswered = false,
    this.selectedAnswerIndex,
  });

  /// 是否有错误
  bool get hasError => error != null;

  /// 当前题目
  KanaQuizQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  /// 正确数
  int get correctCount => results.where((r) => r.isCorrect).length;

  /// 错误数
  int get incorrectCount => results.where((r) => !r.isCorrect).length;

  /// 正确率
  double get accuracy =>
      results.isNotEmpty ? correctCount / results.length : 0.0;

  /// 当前进度 (1-based)
  int get currentProgress => currentIndex + 1;

  /// 总题数
  int get totalCount => questions.length;

  KanaQuizState copyWith({
    bool? isLoading,
    String? error,
    List<KanaQuizQuestion>? questions,
    int? currentIndex,
    List<KanaQuizResult>? results,
    KanaQuizMode? quizMode,
    KanaQuizScope? quizScope,
    bool? isCompleted,
    bool? hasAnswered,
    int? selectedAnswerIndex,
  }) {
    return KanaQuizState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      results: results ?? this.results,
      quizMode: quizMode ?? this.quizMode,
      quizScope: quizScope ?? this.quizScope,
      isCompleted: isCompleted ?? this.isCompleted,
      hasAnswered: hasAnswered ?? this.hasAnswered,
      selectedAnswerIndex: selectedAnswerIndex,
    );
  }
}

/// 测验模式
enum KanaQuizMode {
  kanaToRomaji, // 看假名选罗马音
  romajiToKana, // 看罗马音选假名
  hiraganaToKatakana, // 平假名转片假名
  katakanaToHiragana, // 片假名转平假名
}

/// 测验范围
enum KanaQuizScope {
  learned, // 仅已学习
  all, // 全部
  basic, // 基础假名
  dakuten, // 浊音
  handakuten, // 半浊音
  combo, // 拗音
}

/// 测验题目
class KanaQuizQuestion {
  final KanaLetter kana;
  final String question;
  final List<String> options;
  final int correctIndex;

  const KanaQuizQuestion({
    required this.kana,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  String get correctAnswer => options[correctIndex];
}

/// 测验结果
class KanaQuizResult {
  final KanaLetter kana;
  final int selectedIndex;
  final int correctIndex;
  final bool isCorrect;

  const KanaQuizResult({
    required this.kana,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
  });
}
