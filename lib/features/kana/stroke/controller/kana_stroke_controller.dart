import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/kana_detail.dart';
import '../../../../data/repositories/active_user_provider.dart';
import '../../../../data/repositories/kana_repository.dart';
import '../../../../data/repositories/kana_repository_provider.dart';
import '../../chart/state/kana_chart_state.dart';
import '../state/kana_stroke_state.dart';

/// KanaStrokeController Provider
final kanaStrokeControllerProvider =
    NotifierProvider<KanaStrokeController, KanaStrokeState>(
      KanaStrokeController.new,
    );

/// 假名笔顺练习控制器
class KanaStrokeController extends Notifier<KanaStrokeState> {
  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  @override
  KanaStrokeState build() => const KanaStrokeState();

  /// 初始化练习数据
  Future<void> init({
    required List<KanaLetterWithState> kanaLetters,
    required int initialIndex,
    required KanaDisplayMode displayMode,
  }) async {
    final safeIndex = kanaLetters.isEmpty
        ? 0
        : initialIndex.clamp(0, kanaLetters.length - 1);

    state = state.copyWith(
      kanaLetters: kanaLetters,
      currentIndex: safeIndex,
      displayMode: displayMode,
      error: null,
      isLoading: true,
      svgData: null,
      audioFilename: null,
    );

    await _loadCurrentKana();
  }

  /// 切换到指定索引
  Future<void> goToIndex(int index) async {
    if (index < 0 || index >= state.kanaLetters.length) return;
    state = state.copyWith(
      currentIndex: index,
      isLoading: true,
      error: null,
      svgData: null,
      audioFilename: null,
    );
    await _loadCurrentKana();
  }

  /// 上一个假名
  Future<void> goPrev() async => goToIndex(state.currentIndex - 1);

  /// 下一个假名
  Future<void> goNext() async => goToIndex(state.currentIndex + 1);

  /// 切换显示模式后重新载入笔顺
  Future<void> setDisplayMode(KanaDisplayMode mode) async {
    state = state.copyWith(displayMode: mode, svgData: null, isLoading: true);
    await _loadCurrentKana();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _loadCurrentKana() async {
    final current = state.currentKana;
    if (current == null) {
      state = state.copyWith(isLoading: false, error: '未找到可用的假名');
      return;
    }

    try {
      // --------------------------------------------------
      // ⭐ STEP 2：在这里加载或创建 kana_learning_state
      // --------------------------------------------------
      final user = await ref.read(activeUserProvider.future);

      final learningState = await _kanaRepository.getOrCreateLearningState(
        user.id,
        current.letter.id,
      );

      // 将学习状态存到 Controller 状态里
      state = state.copyWith(learningState: learningState);

      logger.info(
        '五十音学习状态已加载: kanaId=${current.letter.id}, '
        'status=${learningState.learningStatus}',
      );
      // --------------------------------------------------

      final strokeOrder = await _kanaRepository.getKanaStrokeOrder(
        current.letter.id,
      );
      final audio = await _kanaRepository.getKanaAudio(current.letter.id);

      final svg = state.displayMode == KanaDisplayMode.hiragana
          ? strokeOrder?.hiraganaSvg
          : strokeOrder?.katakanaSvg;

      state = state.copyWith(
        isLoading: false,
        svgData: svg,
        audioFilename: audio?.audioFilename,
      );

      logger.info('加载假名笔顺成功: kanaId=${current.letter.id}');
    } catch (e, stackTrace) {
      logger.error('加载假名笔顺失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 记录一次学习动作：更新时间、写日志并同步状态
  Future<void> recordLearningAction() async {
    final current = state.currentKana;
    final learningState = state.learningState;
    if (current == null || learningState == null) return;

    final user = await ref.read(activeUserProvider.future);

    await _kanaRepository.updateLearningTimestamp(user.id, current.letter.id);

    await _kanaRepository.insertLearningLog(
      userId: user.id,
      kanaId: current.letter.id,
      durationMs: 0,
    );

    state = state.copyWith(
      learningState: learningState.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }
}
