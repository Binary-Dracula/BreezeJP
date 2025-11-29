import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/kana_letter.dart';
import '../../../data/repositories/kana_repository.dart';
import '../../../data/repositories/kana_repository_provider.dart';
import '../state/kana_quiz_state.dart';

/// KanaQuizController Provider
final kanaQuizControllerProvider =
    NotifierProvider<KanaQuizController, KanaQuizState>(KanaQuizController.new);

/// 五十音测验控制器
class KanaQuizController extends Notifier<KanaQuizState> {
  final _random = Random();

  @override
  KanaQuizState build() => const KanaQuizState();

  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  /// 开始测验
  Future<void> startQuiz({
    KanaQuizMode mode = KanaQuizMode.kanaToRomaji,
    KanaQuizScope scope = KanaQuizScope.learned,
    int questionCount = 10,
  }) async {
    try {
      logger.info('开始五十音测验: mode=$mode, scope=$scope');
      state = state.copyWith(
        isLoading: true,
        error: null,
        quizMode: mode,
        quizScope: scope,
      );

      // 获取假名列表
      final kanaLetters = await _getKanaLettersByScope(scope);

      if (kanaLetters.length < 4) {
        state = state.copyWith(
          isLoading: false,
          error: '假名数量不足，至少需要4个假名才能开始测验',
        );
        return;
      }

      // 生成题目
      final questions = _generateQuestions(
        kanaLetters,
        mode,
        min(questionCount, kanaLetters.length),
      );

      state = state.copyWith(
        isLoading: false,
        questions: questions,
        currentIndex: 0,
        results: [],
        isCompleted: false,
        hasAnswered: false,
        selectedAnswerIndex: null,
      );

      logger.info('测验初始化完成: ${questions.length}道题');
    } catch (e, stackTrace) {
      logger.error('测验初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 根据范围获取假名列表
  Future<List<KanaLetter>> _getKanaLettersByScope(KanaQuizScope scope) async {
    switch (scope) {
      case KanaQuizScope.learned:
        // 获取已学习的假名
        final allWithState = await _kanaRepository.getAllKanaLettersWithState();
        return allWithState
            .where((k) => k.isLearned)
            .map((k) => k.letter)
            .toList();
      case KanaQuizScope.all:
        return await _kanaRepository.getAllKanaLetters();
      case KanaQuizScope.basic:
        return await _kanaRepository.getKanaLettersByType('basic');
      case KanaQuizScope.dakuten:
        return await _kanaRepository.getKanaLettersByType('dakuten');
      case KanaQuizScope.handakuten:
        return await _kanaRepository.getKanaLettersByType('handakuten');
      case KanaQuizScope.combo:
        return await _kanaRepository.getKanaLettersByType('combo');
    }
  }

  /// 生成测验题目
  List<KanaQuizQuestion> _generateQuestions(
    List<KanaLetter> kanaLetters,
    KanaQuizMode mode,
    int count,
  ) {
    // 随机打乱并取指定数量
    final shuffled = List<KanaLetter>.from(kanaLetters)..shuffle(_random);
    final selected = shuffled.take(count).toList();

    return selected.map((kana) {
      return _createQuestion(kana, kanaLetters, mode);
    }).toList();
  }

  /// 创建单个题目
  KanaQuizQuestion _createQuestion(
    KanaLetter kana,
    List<KanaLetter> allKana,
    KanaQuizMode mode,
  ) {
    String question;
    String correctAnswer;
    List<String> wrongAnswers;

    switch (mode) {
      case KanaQuizMode.kanaToRomaji:
        question = kana.hiragana ?? kana.katakana ?? '';
        correctAnswer = kana.romaji ?? '';
        wrongAnswers = allKana
            .where((k) => k.id != kana.id && k.romaji != null)
            .map((k) => k.romaji!)
            .toSet()
            .toList();
        break;
      case KanaQuizMode.romajiToKana:
        question = kana.romaji ?? '';
        correctAnswer = kana.hiragana ?? kana.katakana ?? '';
        wrongAnswers = allKana
            .where((k) => k.id != kana.id)
            .map((k) => k.hiragana ?? k.katakana ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        break;
      case KanaQuizMode.hiraganaToKatakana:
        question = kana.hiragana ?? '';
        correctAnswer = kana.katakana ?? '';
        wrongAnswers = allKana
            .where((k) => k.id != kana.id && k.katakana != null)
            .map((k) => k.katakana!)
            .toSet()
            .toList();
        break;
      case KanaQuizMode.katakanaToHiragana:
        question = kana.katakana ?? '';
        correctAnswer = kana.hiragana ?? '';
        wrongAnswers = allKana
            .where((k) => k.id != kana.id && k.hiragana != null)
            .map((k) => k.hiragana!)
            .toSet()
            .toList();
        break;
    }

    // 随机选择3个错误答案
    wrongAnswers.shuffle(_random);
    final selectedWrong = wrongAnswers.take(3).toList();

    // 组合选项并打乱
    final options = [correctAnswer, ...selectedWrong]..shuffle(_random);
    final correctIndex = options.indexOf(correctAnswer);

    return KanaQuizQuestion(
      kana: kana,
      question: question,
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// 选择答案
  Future<void> selectAnswer(int answerIndex) async {
    if (state.hasAnswered) return;

    final currentQuestion = state.currentQuestion;
    if (currentQuestion == null) return;

    final isCorrect = answerIndex == currentQuestion.correctIndex;

    // 记录结果
    final result = KanaQuizResult(
      kana: currentQuestion.kana,
      selectedIndex: answerIndex,
      correctIndex: currentQuestion.correctIndex,
      isCorrect: isCorrect,
    );

    state = state.copyWith(
      hasAnswered: true,
      selectedAnswerIndex: answerIndex,
      results: [...state.results, result],
    );

    // 触发触觉反馈
    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    // 记录到数据库
    try {
      await _kanaRepository.addKanaQuizRecord(
        kanaId: currentQuestion.kana.id,
        correct: isCorrect,
      );
    } catch (e, stackTrace) {
      logger.error('记录测验结果失败', e, stackTrace);
    }

    logger.info(
      '回答: ${isCorrect ? '正确' : '错误'} - ${currentQuestion.kana.hiragana}',
    );
  }

  /// 下一题
  void nextQuestion() {
    if (state.currentIndex >= state.questions.length - 1) {
      // 测验完成
      state = state.copyWith(isCompleted: true);
      logger.info('测验完成: 正确${state.correctCount}/${state.totalCount}');
      return;
    }

    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      hasAnswered: false,
      selectedAnswerIndex: null,
    );
  }

  /// 重新开始测验
  Future<void> restartQuiz() async {
    await startQuiz(
      mode: state.quizMode,
      scope: state.quizScope,
      questionCount: state.questions.length,
    );
  }

  /// 重置状态
  void reset() {
    state = const KanaQuizState();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
