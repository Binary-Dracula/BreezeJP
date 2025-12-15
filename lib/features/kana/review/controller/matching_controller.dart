import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../state/matching_pair.dart';
import '../state/matching_state.dart';
import '../state/review_kana_item.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_log.dart';
import '../../../../data/models/user.dart';
import '../../../../data/repositories/kana_repository.dart';
import '../../../../data/repositories/kana_repository_provider.dart';
import '../../../../data/repositories/active_user_provider.dart';

final matchingControllerProvider =
    NotifierProvider<MatchingController, MatchingState>(MatchingController.new);

class MatchingController extends Notifier<MatchingState> {
  KanaRepository get repo => ref.read(kanaRepositoryProvider);
  List<ReviewKanaItem> _audioGroup = [];
  List<ReviewKanaItem> _switchModeGroup = [];
  List<ReviewKanaItem> _recallGroup = [];
  List<KanaLetter>? _allKanaCache;

  @override
  MatchingState build() => const MatchingState();

  /// 加载待复习假名并启动 Matching 流程
  ///
  /// - 有待复习数据：进入 Matching 复习
  /// - 无待复习数据：进入空复习态（isEmpty=true）
  Future<void> loadReview() async {
    try {
      state = state.copyWith(
        isLoading: true,
        isEmpty: false,
        resetCurrentQuestionType: true,
        remaining: const [],
        activePairs: const [],
        selectedLeftIndex: null,
        selectedRightIndex: null,
        isGroupFinished: false,
        isAllFinished: false,
        error: null,
      );

      final user = await ref.read(activeUserProvider.future);
      final learningStates = await repo.getDueReviewKana(user.id);
      final items = await _composeReviewItems(user.id, learningStates);

      if (items.isEmpty) {
        _audioGroup = [];
        _switchModeGroup = [];
        _recallGroup = [];
        state = state.copyWith(
          isLoading: false,
          isEmpty: true,
          resetCurrentQuestionType: true,
          remaining: const [],
          activePairs: const [],
          selectedLeftIndex: null,
          selectedRightIndex: null,
          isGroupFinished: false,
          isAllFinished: false,
          error: null,
        );
        logger.info('暂无待复习假名，进入空复习态');
        return;
      }

      logger.info('启动假名 Matching 复习: ${items.length} 个待复习');
      await startReview(items);
    } catch (e, stackTrace) {
      logger.error('启动假名 Matching 复习失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 初始化所有题型组的队列
  Future<void> startReview(List<ReviewKanaItem> reviewList) async {
    final audioGroup = <ReviewKanaItem>[];
    final switchModeGroup = <ReviewKanaItem>[];
    final recallGroup = <ReviewKanaItem>[];

    for (final item in reviewList) {
      switch (item.questionType) {
        case ReviewQuestionType.audio:
          audioGroup.add(item);
          break;
        case ReviewQuestionType.switchMode:
          switchModeGroup.add(item);
          break;
        case ReviewQuestionType.recall:
          recallGroup.add(item);
          break;
      }
    }

    _audioGroup = audioGroup;
    _switchModeGroup = switchModeGroup;
    _recallGroup = recallGroup;

    state = state.copyWith(
      isLoading: true,
      isEmpty: false,
      resetCurrentQuestionType: true,
      remaining: const [],
      activePairs: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      isAllFinished: false,
      error: null,
    );

    try {
      await startNextGroup();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      logger.error('启动 Matching 下一组失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 开始一个题型组（例如 recallGroup）
  Future<void> startGroup(
    ReviewQuestionType type,
    List<ReviewKanaItem> groupItems,
  ) async {
    if (groupItems.isEmpty) {
      await startNextGroup();
      return;
    }

    final items = List<ReviewKanaItem>.from(groupItems);
    state = state.copyWith(
      isLoading: true,
      isEmpty: false,
      currentQuestionType: type,
      remaining: items,
      activePairs: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      error: null,
    );

    try {
      await generateInitialPairs();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      logger.error('生成 Matching 题目失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 生成初始 activePool（4 对）
  Future<void> generateInitialPairs() async {
    final remaining = List<ReviewKanaItem>.from(state.remaining);
    final active = <MatchingPair>[];

    while (active.length < 4 && remaining.isNotEmpty) {
      final item = remaining.removeAt(0);
      final pair = await generatePairForItem(item);
      active.add(pair);
    }

    state = state.copyWith(activePairs: active, remaining: remaining);
  }

  /// 为某个 item 生成 MatchingPair（含正确项与干扰项）
  Future<MatchingPair> generatePairForItem(ReviewKanaItem item) async {
    final allKana = await _getAllKanaLetters();
    switch (item.questionType) {
      case ReviewQuestionType.recall:
        final left = _kanaDisplay(item.kanaLetter);
        final correct = item.kanaLetter.romaji ?? '';
        final distractors = _pickRecallDistractors(
          item.kanaLetter,
          allKana,
          correct,
        );
        final options = _shuffleOptions(correct, distractors);
        return MatchingPair(
          item: item,
          left: left,
          rightCorrect: correct,
          rightOptions: options,
        );
      case ReviewQuestionType.audio:
        final left = item.audioFilename ?? '';
        final preferKatakana =
            item.kanaLetter.hiragana == null &&
            item.kanaLetter.katakana != null;
        final correct = _kanaDisplay(
          item.kanaLetter,
          preferKatakana: preferKatakana,
        );
        final distractors = _pickAudioDistractors(
          item.kanaLetter,
          allKana,
          correct,
          preferKatakana: preferKatakana,
        );
        final options = _shuffleOptions(correct, distractors);
        return MatchingPair(
          item: item,
          left: left,
          rightCorrect: correct,
          rightOptions: options,
        );
      case ReviewQuestionType.switchMode:
        final left = item.kanaLetter.hiragana ?? '';
        final correct = item.kanaLetter.katakana ?? '';
        final distractors = _pickSwitchModeDistractors(
          item.kanaLetter,
          allKana,
          correct,
        );
        final options = _shuffleOptions(correct, distractors);
        return MatchingPair(
          item: item,
          left: left,
          rightCorrect: correct,
          rightOptions: options,
        );
    }
  }

  /// 用户点击左侧
  void selectLeft(int index) {
    if (index < 0 || index >= state.activePairs.length) return;
    state = state.copyWith(
      selectedLeftIndex: index,
      selectedRightIndex: null,
      error: null,
    );
  }

  /// 用户点击右侧
  Future<void> selectRight(int rightIndex, String selectedValue) async {
    final leftIndex = state.selectedLeftIndex;
    if (leftIndex == null || leftIndex < 0) return;
    if (leftIndex >= state.activePairs.length) return;
    final active = List<MatchingPair>.from(state.activePairs);
    final pair = active[leftIndex];
    if (rightIndex < 0) return;
    if (selectedValue.isEmpty) return;

    final updatedPair = pair.copyWith(attemptCount: pair.attemptCount + 1);
    active[leftIndex] = updatedPair;
    state = state.copyWith(activePairs: active);

    final isCorrect = selectedValue == updatedPair.rightCorrect;
    if (isCorrect) {
      await handleMatchSuccess(leftIndex);
    } else {
      final wrongUpdated = updatedPair.copyWith(
        wrongCount: updatedPair.wrongCount + 1,
      );
      final nextActive = List<MatchingPair>.from(state.activePairs);
      if (leftIndex < nextActive.length) {
        nextActive[leftIndex] = wrongUpdated;
        state = state.copyWith(activePairs: nextActive);
      }
      await handleMatchFailure(leftIndex, rightIndex);
    }
  }

  /// 处理配对成功逻辑
  Future<void> handleMatchSuccess(int leftIndex) async {
    final active = List<MatchingPair>.from(state.activePairs);
    if (leftIndex < 0 || leftIndex >= active.length) return;
    final pair = active[leftIndex];
    final rating = _calculateRating(pair.wrongCount, pair.attemptCount);
    await _onPairRated(pair, rating);
    active.removeAt(leftIndex);

    state = state.copyWith(
      activePairs: active,
      selectedLeftIndex: null,
      selectedRightIndex: null,
      error: null,
    );

    await refillActivePairs();
    await checkGroupFinished();
  }

  /// 处理配对失败逻辑
  Future<void> handleMatchFailure(int leftIndex, int rightIndex) async {
    state = state.copyWith(
      selectedLeftIndex: leftIndex,
      selectedRightIndex: rightIndex,
    );
  }

  /// 补位逻辑：加入新的 pair
  Future<void> refillActivePairs() async {
    final active = List<MatchingPair>.from(state.activePairs);
    final remaining = List<ReviewKanaItem>.from(state.remaining);

    while (active.length < 4 && remaining.isNotEmpty) {
      final item = remaining.removeAt(0);
      final pair = await generatePairForItem(item);
      active.add(pair);
    }

    state = state.copyWith(
      activePairs: active,
      remaining: remaining,
      selectedLeftIndex: null,
      selectedRightIndex: null,
    );
  }

  /// 检查该组是否完成
  Future<void> checkGroupFinished() async {
    if (state.remaining.isEmpty && state.activePairs.isEmpty) {
      state = state.copyWith(isGroupFinished: true);
      await startNextGroup();
    }
  }

  /// 进入下一题型组
  Future<void> startNextGroup() async {
    ReviewQuestionType? nextType;
    List<ReviewKanaItem> nextItems = [];

    if (state.currentQuestionType == null) {
      if (_audioGroup.isNotEmpty) {
        nextType = ReviewQuestionType.audio;
        nextItems = _audioGroup;
        _audioGroup = [];
      } else if (_switchModeGroup.isNotEmpty) {
        nextType = ReviewQuestionType.switchMode;
        nextItems = _switchModeGroup;
        _switchModeGroup = [];
      } else if (_recallGroup.isNotEmpty) {
        nextType = ReviewQuestionType.recall;
        nextItems = _recallGroup;
        _recallGroup = [];
      }
    } else {
      switch (state.currentQuestionType!) {
        case ReviewQuestionType.audio:
          if (_switchModeGroup.isNotEmpty) {
            nextType = ReviewQuestionType.switchMode;
            nextItems = _switchModeGroup;
            _switchModeGroup = [];
          } else if (_recallGroup.isNotEmpty) {
            nextType = ReviewQuestionType.recall;
            nextItems = _recallGroup;
            _recallGroup = [];
          }
          break;
        case ReviewQuestionType.switchMode:
          if (_recallGroup.isNotEmpty) {
            nextType = ReviewQuestionType.recall;
            nextItems = _recallGroup;
            _recallGroup = [];
          }
          break;
        case ReviewQuestionType.recall:
          break;
      }
    }

    if (nextType == null || nextItems.isEmpty) {
      await finishAll();
      return;
    }

    await startGroup(nextType, nextItems);
  }

  /// 所有复习结束
  Future<void> finishAll() async {
    state = state.copyWith(
      isLoading: false,
      isAllFinished: true,
      isGroupFinished: true,
      activePairs: const [],
      remaining: const [],
      resetCurrentQuestionType: true,
      selectedLeftIndex: null,
      selectedRightIndex: null,
    );
  }

  Future<List<KanaLetter>> _getAllKanaLetters() async {
    _allKanaCache ??= await repo.getAllKanaLetters();
    return _allKanaCache!;
  }

  Future<List<ReviewKanaItem>> _composeReviewItems(
    int userId,
    List<KanaLearningState> learningStates,
  ) async {
    final List<ReviewKanaItem> items = [];

    for (final learningState in learningStates) {
      final KanaLetter? letter = await repo.getKanaLetterById(
        learningState.kanaId,
      );
      if (letter == null) {
        logger.warning('假名不存在，跳过复习项: kanaId=${learningState.kanaId}');
        continue;
      }

      final audio = await repo.getKanaAudio(learningState.kanaId);
      final lastType = await repo.getLastKanaReviewQuestionType(
        userId,
        learningState.kanaId,
      );
      final questionType = _chooseQuestionType(learningState, lastType);

      items.add(
        ReviewKanaItem(
          kanaLetter: letter,
          learningState: learningState,
          audioFilename: audio?.audioFilename,
          questionType: questionType,
        ),
      );
    }

    return items;
  }

  ReviewQuestionType _chooseQuestionType(
    KanaLearningState learningState,
    String? lastType,
  ) {
    final level = _judgeLevel(learningState);
    final priorities = switch (level) {
      _SkillLevel.weak => [
        ReviewQuestionType.audio,
        ReviewQuestionType.switchMode,
        ReviewQuestionType.recall,
      ],
      _SkillLevel.newbie => [
        ReviewQuestionType.switchMode,
        ReviewQuestionType.audio,
      ],
      _SkillLevel.strong => [
        ReviewQuestionType.recall,
        ReviewQuestionType.switchMode,
        ReviewQuestionType.audio,
      ],
    };

    final primary = priorities.first;
    final secondary = priorities.length > 1 ? priorities[1] : primary;

    if (lastType != null) {
      final normalizedLast = _mapStringToQuestionType(lastType);
      if (normalizedLast != null && normalizedLast == primary) {
        return secondary;
      }
    }

    return primary;
  }

  _SkillLevel _judgeLevel(KanaLearningState state) {
    if (state.failCount >= 3) return _SkillLevel.weak;
    if (state.streak <= 1) return _SkillLevel.newbie;
    return _SkillLevel.strong;
  }

  ReviewQuestionType? _mapStringToQuestionType(String value) {
    switch (value) {
      case 'recall':
        return ReviewQuestionType.recall;
      case 'audio':
        return ReviewQuestionType.audio;
      case 'switchMode':
        return ReviewQuestionType.switchMode;
      default:
        return null;
    }
  }

  String _kanaDisplay(KanaLetter letter, {bool preferKatakana = false}) {
    if (preferKatakana) {
      return letter.katakana ?? letter.hiragana ?? '';
    }
    return letter.hiragana ?? letter.katakana ?? '';
  }

  List<String> _shuffleOptions(String correct, List<String> distractors) {
    final options = <String>[
      ...distractors.where((d) => d.isNotEmpty).take(3),
      correct,
    ];
    options.removeWhere((option) => option.isEmpty);
    options.shuffle();
    return options;
  }

  List<String> _pickRecallDistractors(
    KanaLetter target,
    List<KanaLetter> allKana,
    String correct,
  ) {
    final result = <String>[];
    void addCandidates(Iterable<KanaLetter> candidates) {
      for (final letter in candidates) {
        final option = letter.romaji ?? '';
        if (letter.id == target.id) continue;
        if (option.isEmpty || option == correct) continue;
        if (result.contains(option)) continue;
        result.add(option);
        if (result.length >= 3) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < 3 && target.type != null) {
      addCandidates(allKana.where((letter) => letter.type == target.type));
    }
    if (result.length < 3) {
      addCandidates(allKana);
    }
    return result.take(3).toList();
  }

  List<String> _pickAudioDistractors(
    KanaLetter target,
    List<KanaLetter> allKana,
    String correct, {
    bool preferKatakana = false,
  }) {
    final result = <String>[];
    void addCandidates(Iterable<KanaLetter> candidates) {
      for (final letter in candidates) {
        if (letter.id == target.id) continue;
        final option = _kanaDisplay(letter, preferKatakana: preferKatakana);
        if (option.isEmpty || option == correct) continue;
        if (result.contains(option)) continue;
        result.add(option);
        if (result.length >= 3) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < 3 && target.type != null) {
      addCandidates(allKana.where((letter) => letter.type == target.type));
    }
    if (result.length < 3) {
      addCandidates(allKana);
    }
    return result.take(3).toList();
  }

  List<String> _pickSwitchModeDistractors(
    KanaLetter target,
    List<KanaLetter> allKana,
    String correct,
  ) {
    final result = <String>[];
    void addCandidates(Iterable<KanaLetter> candidates) {
      for (final letter in candidates) {
        if (letter.id == target.id) continue;
        final option = letter.katakana ?? '';
        if (option.isEmpty || option == correct) continue;
        if (result.contains(option)) continue;
        result.add(option);
        if (result.length >= 3) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < 3) {
      addCandidates(allKana);
    }
    return result.take(3).toList();
  }

  int _calculateRating(int wrongCount, int attemptCount) {
    if (attemptCount == 0) return 2;
    if (wrongCount == 0) return 3;
    if (wrongCount == 1) return 2;
    return 1;
  }

  Future<void> _onPairRated(MatchingPair pair, int rating) async {
    final user = await ref.read(activeUserProvider.future);
    final algorithm = _extractAlgorithm(user);
    final learningState = await repo.getKanaLearningState(
      user.id,
      pair.item.kanaLetter.id,
    );
    if (learningState == null) return;
    final srs = _computeSrsResult(learningState, rating, algorithm);

    await repo.updateKanaReviewResult(
      userId: user.id,
      kanaId: pair.item.kanaLetter.id,
      rating: rating,
      newInterval: srs.newInterval,
      newEaseFactor: srs.newEaseFactor,
      nextReviewAt: srs.nextReviewAt,
    );

    await repo.addKanaLogQuick(
      userId: user.id,
      kanaId: pair.item.kanaLetter.id,
      logType: KanaLogType.review,
      rating: rating,
      algorithm: algorithm,
      intervalAfter: srs.newInterval,
      nextReviewAtAfter: srs.nextReviewAt,
      easeFactorAfter: srs.newEaseFactor,
      fsrsStabilityAfter: srs.newStability,
      fsrsDifficultyAfter: srs.newDifficulty,
      questionType: pair.item.questionType.name,
    );
  }

  SrsResult _computeSrsResult(
    KanaLearningState state,
    int rating,
    int algorithm,
  ) {
    if (algorithm == 2) {
      return SrsResult(
        newInterval: max(1, state.interval),
        newEaseFactor: state.easeFactor,
        nextReviewAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
        newStability: state.stability,
        newDifficulty: state.difficulty,
      );
    }

    return _sm2(state, rating);
  }

  SrsResult _sm2(KanaLearningState state, int rating) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    double interval = state.interval;
    double ef = state.easeFactor;

    if (rating == 1) {
      ef = max(1.3, ef - 0.20);
      interval = 0;
      return SrsResult(
        newInterval: interval,
        newEaseFactor: ef,
        nextReviewAt: now + 600,
      );
    }

    if (rating == 2) {
      if (interval == 0) {
        interval = 1;
      } else {
        interval = interval * ef;
      }
      return SrsResult(
        newInterval: interval,
        newEaseFactor: ef,
        nextReviewAt: now + (interval * 86400).toInt(),
      );
    }

    ef = ef + 0.05;
    interval = max(1, interval * ef * 1.3);
    return SrsResult(
      newInterval: interval,
      newEaseFactor: ef,
      nextReviewAt: now + (interval * 86400).toInt(),
    );
  }

  /// Debug/test helper: simulate a sequence of ratings and return final state + logs.
  Future<Map<String, dynamic>> simulateReviewSequence(
    int userId,
    int kanaId,
    List<int> ratings, {
    String questionType = 'debug',
    int? forceAlgorithm,
  }) async {
    final activeUser = await ref.read(activeUserProvider.future);
    final baseAlgorithm = activeUser.id == userId
        ? _extractAlgorithm(activeUser)
        : 1;
    final algorithm = forceAlgorithm ?? baseAlgorithm;

    for (final rating in ratings) {
      final learningState = await repo.getKanaLearningState(userId, kanaId);
      if (learningState == null) {
        throw StateError(
          'simulateReviewSequence: learningState not found for userId=$userId kanaId=$kanaId',
        );
      }
      final srs = _computeSrsResult(learningState, rating, algorithm);

      await repo.updateKanaReviewResult(
        userId: userId,
        kanaId: kanaId,
        rating: rating,
        newInterval: srs.newInterval,
        newEaseFactor: srs.newEaseFactor,
        nextReviewAt: srs.nextReviewAt,
      );

      await repo.addKanaLogQuick(
        userId: userId,
        kanaId: kanaId,
        logType: KanaLogType.review,
        rating: rating,
        algorithm: algorithm,
        intervalAfter: srs.newInterval,
        nextReviewAtAfter: srs.nextReviewAt,
        easeFactorAfter: srs.newEaseFactor,
        fsrsStabilityAfter: srs.newStability,
        fsrsDifficultyAfter: srs.newDifficulty,
        questionType: questionType,
      );
    }

    final finalState = await repo.getKanaLearningState(userId, kanaId);
    final logs = await repo.getKanaLogs(userId, kanaId);
    return {'finalState': finalState, 'logs': logs};
  }

  int _extractAlgorithm(User user) {
    if (user.settings == null) return 1;
    try {
      final map = jsonDecode(user.settings!) as Map<String, dynamic>;
      final raw = map['srsAlgorithm'] ?? map['srs_algorithm'];
      if (raw is num) {
        final value = raw.toInt();
        if (value == 2) return 2;
      }
    } catch (_) {
      // ignore parse errors, fallback to default
    }
    return 1;
  }
}

class SrsResult {
  final double newInterval;
  final double newEaseFactor;
  final int nextReviewAt;
  final double? newStability;
  final double? newDifficulty;

  SrsResult({
    required this.newInterval,
    required this.newEaseFactor,
    required this.nextReviewAt,
    this.newStability,
    this.newDifficulty,
  });
}

enum _SkillLevel { weak, newbie, strong }
