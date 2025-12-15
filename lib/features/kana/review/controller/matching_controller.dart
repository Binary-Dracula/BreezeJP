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

/// 五十音复习（Matching）控制器
///
/// 该 Controller 负责把「待复习假名队列」组织成 Matching 题目并驱动 UI：
///
/// - 数据来源：`KanaRepository`（通过 `kanaRepositoryProvider` 获取）
/// - 复习入口：UI 应调用 [loadReview] 来启动一次复习 Session
/// - 题型分组：把 [ReviewKanaItem] 按 [ReviewQuestionType] 分为 3 组并按顺序执行
///   - `audio` → `switchMode` → `recall`
/// - 题目结构：每个 [ReviewKanaItem] 会被组装成 1 个 [MatchingPair]
///   - 左侧：`left`（文字或音频 key/文件名）
///   - 右侧：`rightOptions`（包含正确项 + 干扰项）
/// - 屏幕容量：同一时间最多展示 [_maxActivePairs] 对题目（activePairs）
///
/// 状态字段约定（详见 [MatchingState]）：
/// - `isLoading`：表示正在进行异步加载/组装（DB 查询、生成题目等）
/// - `isEmpty`：表示没有任何待复习数据（空复习态），UI 应展示空状态而非 loading
/// - `currentQuestionType`：当前正在复习的题型组；为 null 表示尚未开始或已 reset
/// - `remaining`：当前组尚未进入屏幕的待出题 items
/// - `activePairs`：当前屏幕上展示的题目（最多 4 对）
/// - `selectedLeftIndex/selectedRightIndex`：用户选中状态（以及错误高亮用）
/// - `isGroupFinished/isAllFinished`：本组完成/全部完成标记
class MatchingController extends Notifier<MatchingState> {
  /// 当前屏幕最多展示的 Pair 数量（4 对配对题）。
  static const int _maxActivePairs = 4;

  /// 每个题目的干扰项数量（正确项 + 3 个干扰项）。
  static const int _maxDistractors = 3;

  /// Controller 访问数据库的唯一入口：Repository（禁止 View 直接查 DB）。
  KanaRepository get repo => ref.read(kanaRepositoryProvider);

  /// 待复习队列按题型拆分后的缓存：
  /// - startReview 时一次性分组
  /// - startNextGroup 时按顺序依次消费（消费后会清空对应 list）
  List<ReviewKanaItem> _audioGroup = [];
  List<ReviewKanaItem> _switchModeGroup = [];
  List<ReviewKanaItem> _recallGroup = [];

  /// 干扰项生成需要全量假名集合，缓存以避免重复 DB 查询。
  List<KanaLetter>? _allKanaCache;

  @override
  /// Riverpod Notifier 的 build 仅返回初始 State。
  ///
  /// 注意：这里不会自动触发 [loadReview]，启动入口应由 UI（页面生命周期）明确触发。
  MatchingState build() => const MatchingState();

  void _clearTypeGroups() {
    _audioGroup = [];
    _switchModeGroup = [];
    _recallGroup = [];
  }

  /// 统一的「进入 Session 初始化态」状态写入。
  ///
  /// 该状态用于：
  /// - 进入页面开始加载（isLoading=true）
  /// - 或确认无数据进入空态（isEmpty=true）
  void _setSessionBootstrapState({
    required bool isLoading,
    required bool isEmpty,
  }) {
    state = state.copyWith(
      isLoading: isLoading,
      isEmpty: isEmpty,
      resetCurrentQuestionType: true,
      remaining: const [],
      activePairs: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      isAllFinished: false,
      error: null,
    );
  }

  /// 加载待复习假名并启动 Matching 流程
  ///
  /// - 有待复习数据：进入 Matching 复习
  /// - 无待复习数据：进入空复习态（isEmpty=true）
  Future<void> loadReview() async {
    try {
      _setSessionBootstrapState(isLoading: true, isEmpty: false);

      // 1) 获取当前用户
      final user = await ref.read(activeUserProvider.future);

      // 2) 获取「已到期需复习」的 kana_learning_state
      final learningStates = await repo.getDueReviewKana(user.id);

      // 3) 将 learning_state + kana_letters + kana_audio + 历史题型，组装成 ReviewKanaItem
      final items = await _composeReviewItems(user.id, learningStates);

      // 4) 空数据：进入空复习态（UI 展示空状态，不应一直 loading）
      if (items.isEmpty) {
        _clearTypeGroups();
        _setSessionBootstrapState(isLoading: false, isEmpty: true);
        logger.info('暂无待复习假名，进入空复习态');
        return;
      }

      // 5) 有数据：进入分组 + 出题流程
      logger.info('启动假名 Matching 复习: ${items.length} 个待复习');
      await startReview(items);
    } catch (e, stackTrace) {
      logger.error('启动假名 Matching 复习失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 初始化所有题型组的队列
  ///
  /// 说明：
  /// - 此方法只做「分组」与「启动下一组」
  /// - 实际出题发生在 startGroup → generateInitialPairs
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

    _setSessionBootstrapState(isLoading: true, isEmpty: false);

    try {
      await startNextGroup();
      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      logger.error('启动 Matching 下一组失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 开始一个题型组（例如 recallGroup）
  ///
  /// - 写入当前题型到 state.currentQuestionType
  /// - 将本组 items 填到 state.remaining
  /// - 通过 [generateInitialPairs] 拉取 4 对题目到 state.activePairs
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

    while (active.length < _maxActivePairs && remaining.isNotEmpty) {
      final item = remaining.removeAt(0);
      final pair = await generatePairForItem(item);
      active.add(pair);
    }

    state = state.copyWith(activePairs: active, remaining: remaining);
  }

  /// 为某个 item 生成 MatchingPair（含正确项与干扰项）
  ///
  /// 题型定义：
  /// - recall：左侧显示假名，右侧选罗马音
  /// - audio：左侧存放音频文件名/Key（UI 会负责拼接为 assets 路径并播放），右侧选假名
  /// - switchMode：左侧平假名，右侧选对应片假名
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
  ///
  /// 只记录「当前选中的左侧 index」，并清空右侧选择（等待用户重新选择右侧项）。
  void selectLeft(int index) {
    if (index < 0 || index >= state.activePairs.length) return;
    state = state.copyWith(
      selectedLeftIndex: index,
      selectedRightIndex: null,
      error: null,
    );
  }

  /// 用户点击右侧
  ///
  /// 流程：
  /// 1) 必须先选中左侧（selectedLeftIndex != null）
  /// 2) 为该 Pair 增加 attemptCount
  /// 3) 若匹配正确：进入 [handleMatchSuccess]
  /// 4) 若匹配错误：增加 wrongCount + 记录右侧选中 index（用于 UI 高亮）
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
  ///
  /// - 将错误次数/尝试次数映射为 rating（1/2/3）
  /// - 写入复习结果到学习进度（kana_learning_state）
  /// - 写入复习日志（kana_logs）
  /// - 从 activePairs 移除已完成的 Pair，并触发补位/组完成检查
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
  ///
  /// 仅写入选择状态，UI 可据此展示错误高亮/震动等反馈。
  Future<void> handleMatchFailure(int leftIndex, int rightIndex) async {
    state = state.copyWith(
      selectedLeftIndex: leftIndex,
      selectedRightIndex: rightIndex,
    );
  }

  /// 补位逻辑：加入新的 pair
  ///
  /// 当 activePairs 少于 [_maxActivePairs] 时，从 remaining 取出新的 item 生成 pair 补齐。
  Future<void> refillActivePairs() async {
    final active = List<MatchingPair>.from(state.activePairs);
    final remaining = List<ReviewKanaItem>.from(state.remaining);

    while (active.length < _maxActivePairs && remaining.isNotEmpty) {
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
  ///
  /// 组完成条件：remaining 与 activePairs 均为空。
  /// 达成后会标记 isGroupFinished 并自动进入下一题型组。
  Future<void> checkGroupFinished() async {
    if (state.remaining.isEmpty && state.activePairs.isEmpty) {
      state = state.copyWith(isGroupFinished: true);
      await startNextGroup();
    }
  }

  /// 进入下一题型组
  ///
  /// 分组顺序固定：
  /// - 首组：audio → switchMode → recall
  /// - 后续：从当前题型向后推进（audio 后不会回到 audio）
  ///
  /// 注意：
  /// - 本方法会「消费」对应的 `_xxxGroup`（取出后置空），避免重复进入同一组
  /// - 若不存在下一组，则进入 [finishAll]
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
  ///
  /// 设置终止态给 UI：
  /// - isAllFinished=true
  /// - 清空题目与剩余队列
  /// - resetCurrentQuestionType=true（避免 UI 因 null/旧值判断异常）
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

  /// 获取全量假名集合（用于干扰项生成），并做内存缓存。
  Future<List<KanaLetter>> _getAllKanaLetters() async {
    _allKanaCache ??= await repo.getAllKanaLetters();
    return _allKanaCache!;
  }

  /// 将「待复习学习进度记录」组装为 UI 出题所需的 [ReviewKanaItem] 列表。
  ///
  /// 组装内容：
  /// - kana_letters：用于显示（平/片/罗马音）
  /// - kana_audio：audio 题型需要音频文件名/Key
  /// - last question type：用于尽量避免连续重复同一题型
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

  /// 根据学习状态与历史题型，选择本次要出的题型。
  ///
  /// 规则概要：
  /// - 先根据学习状态判定「强/新/弱」等级（[_judgeLevel]）
  /// - 不同等级有不同的题型优先级
  /// - 若上一次题型与本次首选题型相同，则降级为次选题型（减少重复）
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

  /// 粗略评估掌握程度，用于题型策略（不涉及 SRS 算法推导）。
  _SkillLevel _judgeLevel(KanaLearningState learningState) {
    if (learningState.failCount >= 3) return _SkillLevel.weak;
    if (learningState.streak <= 1) return _SkillLevel.newbie;
    return _SkillLevel.strong;
  }

  /// 将数据库/日志存储的 questionType 字符串映射为枚举。
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

  /// 根据假名字母模型，决定在 UI 中显示的字符（平/片假名）。
  ///
  /// - preferKatakana=true：优先显示片假名（例如该条目缺失 hiragana 时）
  String _kanaDisplay(KanaLetter letter, {bool preferKatakana = false}) {
    if (preferKatakana) {
      return letter.katakana ?? letter.hiragana ?? '';
    }
    return letter.hiragana ?? letter.katakana ?? '';
  }

  /// 将正确项与干扰项组装成右侧选项列表并随机打乱。
  List<String> _shuffleOptions(String correct, List<String> distractors) {
    final options = <String>[
      ...distractors.where((d) => d.isNotEmpty).take(_maxDistractors),
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
        if (result.length >= _maxDistractors) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < _maxDistractors && target.type != null) {
      addCandidates(allKana.where((letter) => letter.type == target.type));
    }
    if (result.length < _maxDistractors) {
      addCandidates(allKana);
    }
    return result.take(_maxDistractors).toList();
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
        if (result.length >= _maxDistractors) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < _maxDistractors && target.type != null) {
      addCandidates(allKana.where((letter) => letter.type == target.type));
    }
    if (result.length < _maxDistractors) {
      addCandidates(allKana);
    }
    return result.take(_maxDistractors).toList();
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
        if (result.length >= _maxDistractors) return;
      }
    }

    if (target.kanaGroup != null) {
      addCandidates(
        allKana.where((letter) => letter.kanaGroup == target.kanaGroup),
      );
    }
    if (result.length < _maxDistractors) {
      addCandidates(allKana);
    }
    return result.take(_maxDistractors).toList();
  }

  /// 将一次 Pair 的表现映射为 SRS rating（1/2/3）。
  ///
  /// 规则：
  /// - 0 次尝试（理论上不会发生）：按中等（2）处理
  /// - 0 次错误：好（3）
  /// - 1 次错误：中（2）
  /// - >=2 次错误：差（1）
  int _calculateRating(int wrongCount, int attemptCount) {
    if (attemptCount == 0) return 2;
    if (wrongCount == 0) return 3;
    if (wrongCount == 1) return 2;
    return 1;
  }

  /// 在用户完成一个 Pair 后，将结果落库（更新学习进度 + 追加日志）。
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

  /// 根据算法类型生成新的复习结果（interval/ef/nextReviewAt 等）。
  ///
  /// 说明：
  /// - algorithm=1：使用本 Controller 内的简化 SM-2（[_sm2]）
  /// - algorithm=2：目前为占位实现（不推导 FSRS），保持原逻辑不变
  SrsResult _computeSrsResult(
    KanaLearningState learningState,
    int rating,
    int algorithm,
  ) {
    if (algorithm == 2) {
      return SrsResult(
        newInterval: max(1, learningState.interval),
        newEaseFactor: learningState.easeFactor,
        nextReviewAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
        newStability: learningState.stability,
        newDifficulty: learningState.difficulty,
      );
    }

    return _sm2(learningState, rating);
  }

  /// 简化 SM-2（保持现有实现，不在此处做更复杂的算法推导）。
  SrsResult _sm2(KanaLearningState learningState, int rating) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    double interval = learningState.interval;
    double ef = learningState.easeFactor;

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

  /// Debug/Test：模拟一串评分序列，并返回最终 learningState 与 logs。
  ///
  /// 注意：该方法会直接写入数据库（通过 Repository），仅用于开发测试。
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

  /// 从用户 settings 中提取 SRS 算法开关：
  /// - 默认 1（SM-2）
  /// - settings 支持 key：srsAlgorithm / srs_algorithm
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

/// 一次复习操作的结果集合（用于落库与日志记录）。
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
