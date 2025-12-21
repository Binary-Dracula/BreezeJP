import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../state/matching_state.dart';
import '../state/review_kana_item.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_log.dart';
import '../../../../data/models/user.dart';
import '../../../../data/commands/active_user_command.dart';
import '../../../../data/commands/active_user_command_provider.dart';
import '../../../../data/commands/kana_command.dart';
import '../../../../data/commands/kana_command_provider.dart';
import '../../../../data/commands/session/session_scope.dart';
import '../../../../data/commands/session/study_session_handle.dart';
import '../../../../data/commands/study_session_command_provider.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/queries/kana_query.dart';
import '../../../../data/queries/kana_query_provider.dart';

final matchingControllerProvider =
    NotifierProvider<MatchingController, MatchingState>(MatchingController.new);

/// 五十音复习（Matching）控制器
///
/// 该 Controller 负责把「待复习假名队列」组织成 Matching 题目并驱动 UI。
///
/// - 数据来源：`KanaQuery`（通过 `kanaQueryProvider` 获取）
/// - 复习入口：UI 应调用 [loadReview] 来启动一次复习 Session
/// - 题型分组：把 [ReviewKanaItem] 按 [ReviewQuestionType] 分为 3 组并按顺序执行
///   - `audio` → `switchMode` → `recall`
/// - 出题模型：最多 4×4 一一对应 Pair Window
///   - 左右两侧数量与当前组可出题数量一致（最多 4 个）
///   - 系统内部维护最多 4 个 [MatchingPair]（一一对应）
///   - 右侧仅做乱序显示，但仍一一对应（通过 [RightOption.pairIndex] 指向 activePairs）
///
/// 状态字段约定（详见 [MatchingState]）：
/// - `isLoading`：表示正在进行异步加载/组装（DB 查询、生成题目等）
/// - `isEmpty`：表示没有任何待复习数据（空复习态），UI 应展示空状态而非 loading
/// - `currentQuestionType`：当前正在复习的题型组；为 null 表示尚未开始或已 reset
/// - `activePairs/remainingItems`：当前组的 Pair Window（activePairs 最多 4）
/// - `rightOptions`：右侧选项（乱序展示，但仍指向 activePairs）
/// - `selectedLeftIndex/selectedRightIndex`：用户当前选中项（允许先选左或先选右）
/// - `isGroupFinished/isAllFinished`：本组完成/全部完成标记
class MatchingController extends Notifier<MatchingState> {
  /// 4×4 Pair Window 的最大尺寸。
  static const int _windowSize = 4;

  /// Controller 访问查询的入口：KanaQuery（禁止 View 直接查 DB）。
  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  KanaCommand get _kanaCommand => ref.read(kanaCommandProvider);
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  StudySessionHandle? _session;

  /// 待复习队列按题型拆分后的缓存：
  /// - startReview 时一次性分组
  /// - startNextGroup 时按顺序依次消费（消费后会清空对应 list）
  List<ReviewKanaItem> _audioGroup = [];
  List<ReviewKanaItem> _switchModeGroup = [];
  List<ReviewKanaItem> _recallGroup = [];

  /// 防止「选中左右 → 判定 → 落库/补位」流程重入（例如连点导致多次触发）。
  bool _isResolvingSelection = false;

  /// 记录每个 kana 在本次出题中的尝试次数/错误次数（用于计算 rating）。
  ///
  /// key：kana_id
  final Map<int, int> _attemptCountByKanaId = {};
  final Map<int, int> _wrongCountByKanaId = {};

  @override
  /// Riverpod Notifier 的 build 仅返回初始 State。
  ///
  /// 注意：这里不会自动触发 [loadReview]，启动入口应由 UI（页面生命周期）明确触发。
  MatchingState build() => const MatchingState();

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

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
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
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
      _attemptCountByKanaId.clear();
      _wrongCountByKanaId.clear();

      // 1) 获取当前用户
      final user = await _getActiveUser();
      await _session?.flush();
      _session =
          ref.read(studySessionCommandProvider).createSession(
                userId: user.id,
                scope: SessionScope.kanaReview,
              );

      // 2) 获取「已到期需复习」的 kana_learning_state
      final learningStates = await _kanaQuery.getDueReviewKana(user.id);

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
  /// - 实际出题发生在 startGroup → _buildInitialPairs
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
  /// - 生成最多 4 对 activePairs（4×4 Pair Window）
  /// - 右侧仅乱序展示（RightOption.pairIndex 指向 activePairs）
  Future<void> startGroup(
    ReviewQuestionType type,
    List<ReviewKanaItem> groupItems,
  ) async {
    if (groupItems.isEmpty) {
      await startNextGroup();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isEmpty: false,
      currentQuestionType: type,
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
      selectedLeftIndex: null,
      selectedRightIndex: null,
      isGroupFinished: false,
      error: null,
    );

    try {
      _attemptCountByKanaId.clear();
      _wrongCountByKanaId.clear();

      final split = _buildInitialPairs(groupItems);
      final activePairs = split.activePairs;
      final remaining = split.remainingItems;

      if (activePairs.isEmpty && remaining.isEmpty) {
        await startNextGroup();
        return;
      }

      final rightOptions = _buildShuffledRightOptions(activePairs);

      state = state.copyWith(
        isLoading: false,
        activePairs: activePairs,
        remainingItems: remaining,
        rightOptions: rightOptions,
        selectedLeftIndex: null,
        selectedRightIndex: null,
        isGroupFinished: false,
        error: null,
      );
    } catch (e, stackTrace) {
      logger.error('生成 Matching 题目失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 选择左侧配对项（允许先选左或先选右）。
  Future<void> selectLeft(int index) async {
    if (_isResolvingSelection) return;
    if (index < 0 || index >= state.activePairs.length) return;
    if (state.activePairs[index].isMatched) return;

    final next = state.selectedLeftIndex == index ? null : index;
    state = state.copyWith(selectedLeftIndex: next, error: null);
    await _tryResolveSelection();
  }

  /// 选择右侧选项（允许先选左或先选右）。
  Future<void> selectRight(int rightIndex) async {
    if (_isResolvingSelection) return;
    if (rightIndex < 0 || rightIndex >= state.rightOptions.length) return;

    final option = state.rightOptions[rightIndex];
    if (option.pairIndex < 0 || option.pairIndex >= state.activePairs.length) {
      return;
    }
    if (state.activePairs[option.pairIndex].isMatched) return;

    final next = state.selectedRightIndex == rightIndex ? null : rightIndex;
    state = state.copyWith(selectedRightIndex: next, error: null);
    await _tryResolveSelection();
  }

  Future<void> _tryResolveSelection() async {
    if (_isResolvingSelection) return;

    final selectedLeftIndex = state.selectedLeftIndex;
    final selectedRightIndex = state.selectedRightIndex;
    if (selectedLeftIndex == null || selectedRightIndex == null) return;

    if (selectedLeftIndex < 0 ||
        selectedLeftIndex >= state.activePairs.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }
    if (selectedRightIndex < 0 ||
        selectedRightIndex >= state.rightOptions.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final rightPairIndex = state.rightOptions[selectedRightIndex].pairIndex;
    if (rightPairIndex < 0 || rightPairIndex >= state.activePairs.length) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final pair = state.activePairs[selectedLeftIndex];
    if (pair.isMatched) {
      state = state.copyWith(selectedLeftIndex: null, selectedRightIndex: null);
      return;
    }

    final kanaId = pair.item.kanaLetter.id;
    final attemptCount = (_attemptCountByKanaId[kanaId] ?? 0) + 1;
    _attemptCountByKanaId[kanaId] = attemptCount;

    // 关键判定逻辑：左侧 index 必须等于右侧选项的 pairIndex。
    final isCorrect = selectedLeftIndex == rightPairIndex;
    if (!isCorrect) {
      _wrongCountByKanaId[kanaId] = (_wrongCountByKanaId[kanaId] ?? 0) + 1;
      _isResolvingSelection = true;
      try {
        await Future.delayed(const Duration(milliseconds: 420));
        state = state.copyWith(
          selectedLeftIndex: null,
          selectedRightIndex: null,
          error: null,
        );
      } finally {
        _isResolvingSelection = false;
      }
      return;
    }

    _isResolvingSelection = true;
    try {
      await _handleCorrectMatch(
        pairIndex: selectedLeftIndex,
        pair: pair,
        attemptCount: attemptCount,
      );
    } catch (e, stackTrace) {
      logger.error('处理配对成功失败', e, stackTrace);
      state = state.copyWith(error: e.toString());
    } finally {
      _isResolvingSelection = false;
    }
  }

  Future<void> _handleCorrectMatch({
    required int pairIndex,
    required MatchingPair pair,
    required int attemptCount,
  }) async {
    final kanaId = pair.item.kanaLetter.id;
    final wrongCount = _wrongCountByKanaId[kanaId] ?? 0;
    final rating = _calculateRating(wrongCount, attemptCount);

    await _onItemRated(pair.item, rating);

    _attemptCountByKanaId.remove(kanaId);
    _wrongCountByKanaId.remove(kanaId);

    final activePairs = List<MatchingPair>.from(state.activePairs);
    if (pairIndex < 0 || pairIndex >= activePairs.length) return;

    final remaining = List<ReviewKanaItem>.from(state.remainingItems);

    // remaining 非空：移除该 pair，并从 remaining 补 1 对，右侧整体重新 shuffle。
    if (remaining.isNotEmpty) {
      activePairs.removeAt(pairIndex);
      final nextItem = remaining.removeAt(0);
      activePairs.insert(pairIndex, _pairForItem(nextItem));

      state = state.copyWith(
        activePairs: activePairs,
        remainingItems: remaining,
        rightOptions: _buildShuffledRightOptions(activePairs),
        selectedLeftIndex: null,
        selectedRightIndex: null,
        error: null,
      );
      return;
    }

    // remaining 为空：标记该 pair 为 isMatched，不移除，不补充。
    final current = activePairs[pairIndex];
    activePairs[pairIndex] = MatchingPair(
      item: current.item,
      left: current.left,
      right: current.right,
      isMatched: true,
    );

    state = state.copyWith(
      activePairs: activePairs,
      selectedLeftIndex: null,
      selectedRightIndex: null,
      error: null,
    );

    // remaining 为空且全部 isMatched：本组结束。
    if (remaining.isEmpty && activePairs.every((p) => p.isMatched)) {
      state = state.copyWith(isGroupFinished: true);
      await startNextGroup();
    }
  }

  ({List<MatchingPair> activePairs, List<ReviewKanaItem> remainingItems})
  _buildInitialPairs(List<ReviewKanaItem> groupItems) {
    final activePairs = <MatchingPair>[];
    final remaining = <ReviewKanaItem>[];

    for (final item in groupItems) {
      final pair = _pairForItem(item);
      final left = pair.left.trim();
      final right = pair.right.trim();
      final leftOk =
          item.questionType == ReviewQuestionType.audio || left.isNotEmpty;

      if (!leftOk || right.isEmpty) {
        logger.warning(
          '复习条目缺少配对内容，跳过: kanaId=${item.kanaLetter.id} type=${item.questionType.name}',
        );
        continue;
      }

      if (activePairs.length < _windowSize) {
        activePairs.add(pair);
      } else {
        remaining.add(item);
      }
    }

    if (activePairs.isEmpty) {
      return (activePairs: const [], remainingItems: const []);
    }

    return (activePairs: activePairs, remainingItems: remaining);
  }

  MatchingPair _pairForItem(ReviewKanaItem item) {
    return MatchingPair(
      item: item,
      left: _leftValueForItem(item),
      right: _rightValueForItem(item),
      isMatched: false,
    );
  }

  List<RightOption> _buildShuffledRightOptions(List<MatchingPair> activePairs) {
    final options = <RightOption>[
      for (var i = 0; i < activePairs.length; i++)
        RightOption(pairIndex: i, value: activePairs[i].right),
    ];
    options.shuffle();
    return options;
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
    _attemptCountByKanaId.clear();
    _wrongCountByKanaId.clear();
    state = state.copyWith(
      isLoading: false,
      isAllFinished: true,
      isGroupFinished: true,
      activePairs: const [],
      remainingItems: const [],
      rightOptions: const [],
      resetCurrentQuestionType: true,
      selectedLeftIndex: null,
      selectedRightIndex: null,
    );
    await _flushSession();
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
      final KanaLetter? letter = await _kanaQuery.getKanaLetterById(
        learningState.kanaId,
      );
      if (letter == null) {
        logger.warning('假名不存在，跳过复习项: kanaId=${learningState.kanaId}');
        continue;
      }

      final audio = await _kanaQuery.getKanaAudio(learningState.kanaId);
      final lastType = await _kanaQuery.getLastKanaReviewQuestionType(
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

  String _leftValueForItem(ReviewKanaItem item) {
    switch (item.questionType) {
      case ReviewQuestionType.audio:
        return '';
      case ReviewQuestionType.recall:
        return _kanaDisplay(item.kanaLetter);
      case ReviewQuestionType.switchMode:
        return _kanaDisplay(item.kanaLetter);
    }
  }

  String _rightValueForItem(ReviewKanaItem item) {
    switch (item.questionType) {
      case ReviewQuestionType.recall:
        return item.kanaLetter.romaji ?? '';
      case ReviewQuestionType.audio:
        final preferKatakana =
            item.kanaLetter.hiragana == null &&
            item.kanaLetter.katakana != null;
        return _kanaDisplay(item.kanaLetter, preferKatakana: preferKatakana);
      case ReviewQuestionType.switchMode:
        final hiragana = item.kanaLetter.hiragana;
        final katakana = item.kanaLetter.katakana;
        if (hiragana != null &&
            hiragana.isNotEmpty &&
            katakana != null &&
            katakana.isNotEmpty) {
          return katakana;
        }
        return katakana ?? hiragana ?? '';
    }
  }

  /// 将一次题目的表现映射为 SRS rating（1/2/3）。
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

  /// 在用户完成一个题目后，将结果落库（更新学习进度 + 追加日志）。
  Future<void> _onItemRated(ReviewKanaItem item, int rating) async {
    final user = await _getActiveUser();
    final algorithm = _extractAlgorithm(user);
    final learningState = await _kanaQuery.getKanaLearningState(
      user.id,
      item.kanaLetter.id,
    );
    if (learningState == null) return;
    final srs = _computeSrsResult(learningState, rating, algorithm);

    await _kanaCommand.updateKanaReviewResult(
      userId: user.id,
      kanaId: item.kanaLetter.id,
      rating: rating,
      newInterval: srs.newInterval,
      newEaseFactor: srs.newEaseFactor,
      nextReviewAt: srs.nextReviewAt,
    );

    final session =
        _session ??
        ref.read(studySessionCommandProvider).createSession(
              userId: user.id,
              scope: SessionScope.kanaReview,
            );
    _session ??= session;

    await _kanaCommand.addKanaLogQuick(
      userId: user.id,
      kanaId: item.kanaLetter.id,
      logType: KanaLogType.review,
      rating: rating,
      algorithm: algorithm,
      intervalAfter: srs.newInterval,
      nextReviewAtAfter: srs.nextReviewAt,
      easeFactorAfter: srs.newEaseFactor,
      fsrsStabilityAfter: srs.newStability,
      fsrsDifficultyAfter: srs.newDifficulty,
      questionType: item.questionType.name,
      session: session,
    );
  }

  Future<void> endSession() async {
    await _flushSession();
  }

  Future<void> _flushSession() async {
    try {
      await _session?.flush();
    } catch (e, stackTrace) {
      logger.error('假名复习 Session flush 失败', e, stackTrace);
    } finally {
      _session = null;
    }
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
