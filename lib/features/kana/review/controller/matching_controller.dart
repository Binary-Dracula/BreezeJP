import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/matching_pair.dart';
import '../state/matching_state.dart';
import '../state/kana_review_state.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/repositories/kana_repository.dart';
import '../../../../data/repositories/kana_repository_provider.dart';

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
      currentQuestionType: null,
      remaining: const [],
      activePairs: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      isAllFinished: false,
      error: null,
    );

    await startNextGroup();
    state = state.copyWith(isLoading: false);
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
      currentQuestionType: type,
      remaining: items,
      activePairs: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      error: null,
    );

    await generateInitialPairs();
    state = state.copyWith(isLoading: false);
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
  void selectRight(int index) async {
    final leftIndex = state.selectedLeftIndex;
    if (leftIndex == null || leftIndex < 0) return;
    if (leftIndex >= state.activePairs.length) return;
    final pair = state.activePairs[leftIndex];
    if (index < 0 || index >= pair.rightOptions.length) return;

    final isCorrect = pair.rightOptions[index] == pair.rightCorrect;
    if (isCorrect) {
      await handleMatchSuccess(leftIndex, index);
    } else {
      await handleMatchFailure(leftIndex, index);
    }
  }

  /// 处理配对成功逻辑
  Future<void> handleMatchSuccess(int leftIndex, int rightIndex) async {
    final active = List<MatchingPair>.from(state.activePairs);
    if (leftIndex < 0 || leftIndex >= active.length) return;
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
      isAllFinished: true,
      isGroupFinished: true,
      activePairs: const [],
      remaining: const [],
      currentQuestionType: null,
      selectedLeftIndex: null,
      selectedRightIndex: null,
    );
  }

  Future<List<KanaLetter>> _getAllKanaLetters() async {
    _allKanaCache ??= await repo.getAllKanaLetters();
    return _allKanaCache!;
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
}
