import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/domain_event_bus.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/kana_detail.dart';
import '../../../../data/commands/kana_command.dart';
import '../../../../data/commands/kana_command_provider.dart';
import '../../../../data/commands/active_user_command.dart';
import '../../../../data/commands/active_user_command_provider.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/models/user.dart';
import '../../../../data/queries/kana_query.dart';
import '../../../../data/queries/kana_query_provider.dart';
import '../../chart/state/kana_chart_state.dart';
import '../state/kana_stroke_state.dart';

/// KanaStrokeController Provider
final kanaStrokeControllerProvider =
    NotifierProvider<KanaStrokeController, KanaStrokeState>(
      KanaStrokeController.new,
    );

/// 假名笔顺练习控制器
class KanaStrokeController extends Notifier<KanaStrokeState> {
  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  KanaCommand get _kanaCommand => ref.read(kanaCommandProvider);
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  @override
  KanaStrokeState build() => const KanaStrokeState();

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  /// 初始化练习数据
  Future<void> init({
    required List<KanaLetterWithState> kanaLetters,
    required int initialIndex,
    required KanaDisplayMode displayMode,
  }) async {
    final safeIndex = kanaLetters.isEmpty
        ? 0
        : initialIndex.clamp(0, kanaLetters.length - 1);
    final currentKanaId =
        kanaLetters.isEmpty ? null : kanaLetters[safeIndex].letter.id;

    state = state.copyWith(
      kanaLetters: kanaLetters,
      currentIndex: safeIndex,
      currentKanaId: currentKanaId,
      displayMode: displayMode,
      error: null,
      isLoading: true,
      learningState: null,
      svgData: null,
      audioFilename: null,
    );

    await _loadCurrentKana();
  }

  /// 切换到指定索引
  Future<void> goToIndex(int index) async {
    if (index < 0 || index >= state.kanaLetters.length) return;
    final currentKanaId = state.kanaLetters[index].letter.id;
    state = state.copyWith(
      currentIndex: index,
      currentKanaId: currentKanaId,
      isLoading: true,
      error: null,
      learningState: null,
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

    final requestedKanaId = current.letter.id;
    state = state.copyWith(
      currentKanaId: requestedKanaId,
      learningState: null,
    );

    try {
      final user = await _getActiveUser();
      if (state.currentKanaId != requestedKanaId) {
        return;
      }
      final learningState = await _kanaQuery.getKanaLearningState(
        user.id,
        requestedKanaId,
      );
      if (state.currentKanaId != requestedKanaId) {
        return;
      }
      state = state.copyWith(
        currentKanaId: requestedKanaId,
        learningState: learningState,
      );

      if (learningState != null) {
        logger.info(
          '五十音学习状态已加载: kanaId=$requestedKanaId, '
          'status=${learningState.learningStatus}',
        );
      }

      final strokeOrder = await _kanaQuery.getKanaStrokeOrder(
        requestedKanaId,
      );
      if (state.currentKanaId != requestedKanaId) {
        return;
      }
      final audio = await _kanaQuery.getKanaAudioByKanaId(requestedKanaId);
      if (state.currentKanaId != requestedKanaId) {
        return;
      }

      final svg = strokeOrder?.svg;

      state = state.copyWith(
        isLoading: false,
        svgData: svg,
        audioFilename: audio?.audioFilename,
      );

      logger.info('加载假名笔顺成功: kanaId=$requestedKanaId');
    } catch (e, stackTrace) {
      if (state.currentKanaId != requestedKanaId) {
        return;
      }
      logger.error('加载假名笔顺失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 描红完成后创建 learning 状态（仅首次）
  Future<void> onKanaTraceCompleted(int kanaId) async {
    final user = await _getActiveUser();
    final event = await _kanaCommand.onKanaPracticed(
      userId: user.id,
      kanaId: kanaId,
    );
    if (event != null) {
      DomainEventBus().publish(event);
    }
    await refreshState();
  }

  /// 切换当前假名掌握状态（learning ↔ mastered）
  Future<void> toggleKanaMastered(int kanaId) async {
    final user = await _getActiveUser();
    final event = await _kanaCommand.toggleKanaMastered(
      userId: user.id,
      kanaId: kanaId,
    );
    if (event != null) {
      DomainEventBus().publish(event);
    }
    await refreshState();
  }

  /// 刷新当前假名的学习状态
  Future<void> refreshState() async {
    final current = state.currentKana;
    if (current == null) return;
    final requestedKanaId = current.letter.id;
    state = state.copyWith(
      currentKanaId: requestedKanaId,
      learningState: null,
    );
    final user = await _getActiveUser();
    if (state.currentKanaId != requestedKanaId) {
      return;
    }
    final learningState = await _kanaQuery.getKanaLearningState(
      user.id,
      requestedKanaId,
    );
    if (state.currentKanaId != requestedKanaId) {
      return;
    }

    state = state.copyWith(
      currentKanaId: requestedKanaId,
      learningState: learningState,
    );
  }
}
