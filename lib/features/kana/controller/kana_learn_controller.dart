import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/kana_letter.dart';
import '../../../data/repositories/kana_repository.dart';
import '../../../data/repositories/kana_repository_provider.dart';
import '../state/kana_learn_state.dart';

/// KanaLearnController Provider
final kanaLearnControllerProvider =
    NotifierProvider<KanaLearnController, KanaLearnState>(
      KanaLearnController.new,
    );

/// 五十音学习控制器
class KanaLearnController extends Notifier<KanaLearnState> {
  @override
  KanaLearnState build() => const KanaLearnState();

  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  /// 初始化学习（传入假名类型）
  /// type: basic/dakuten/handakuten/combo, null=全部
  Future<void> initWithType(String? type) async {
    try {
      logger.info('开始初始化五十音学习: type=${type ?? '全部'}');
      state = state.copyWith(isLoading: true, error: null);

      // 获取假名列表
      List<KanaLetter> kanaLetters;
      if (type != null) {
        kanaLetters = await _kanaRepository.getKanaLettersByType(type);
      } else {
        kanaLetters = await _kanaRepository.getAllKanaLetters();
      }

      if (kanaLetters.isEmpty) {
        state = state.copyWith(isLoading: false, error: '没有找到假名');
        return;
      }

      // 加载第一个假名的详情
      final firstDetail = await _kanaRepository.getKanaDetail(
        kanaLetters.first.id,
      );

      state = state.copyWith(
        isLoading: false,
        studyQueue: kanaLetters,
        currentIndex: 0,
        currentKanaDetail: firstDetail,
        learnedKanaIds: {},
      );

      logger.info('五十音学习初始化完成: ${kanaLetters.length}个假名');
    } catch (e, stackTrace) {
      logger.error('五十音学习初始化失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 初始化学习（传入指定假名 ID）
  Future<void> initWithKanaId(int kanaId) async {
    try {
      logger.info('开始学习假名: kanaId=$kanaId');
      state = state.copyWith(isLoading: true, error: null);

      // 获取假名详情
      final detail = await _kanaRepository.getKanaDetail(kanaId);
      if (detail == null) {
        state = state.copyWith(isLoading: false, error: '假名不存在');
        return;
      }

      state = state.copyWith(
        isLoading: false,
        studyQueue: [detail.letter],
        currentIndex: 0,
        currentKanaDetail: detail,
      );

      logger.info('假名详情加载成功: ${detail.letter.hiragana}');
    } catch (e, stackTrace) {
      logger.error('加载假名详情失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 页面切换回调
  Future<void> onPageChanged(int newIndex) async {
    final oldIndex = state.currentIndex;

    // 向前滑动时标记上一个假名为已学习
    if (newIndex > oldIndex && oldIndex < state.studyQueue.length) {
      final previousKanaId = state.studyQueue[oldIndex].id;
      if (!state.learnedKanaIds.contains(previousKanaId)) {
        await markKanaAsLearned(previousKanaId);
      }
    }

    // 更新当前索引
    state = state.copyWith(currentIndex: newIndex);

    // 触发触觉反馈
    HapticFeedback.lightImpact();

    // 加载当前假名详情
    if (newIndex < state.studyQueue.length) {
      await loadCurrentKanaDetail();
    }

    logger.info('切换假名: ${newIndex + 1}/${state.studyQueue.length}');
  }

  /// 加载当前假名详情
  Future<void> loadCurrentKanaDetail() async {
    final currentKana = state.currentKana;
    if (currentKana == null) return;

    try {
      final detail = await _kanaRepository.getKanaDetail(currentKana.id);
      state = state.copyWith(currentKanaDetail: detail);
    } catch (e, stackTrace) {
      logger.error('加载假名详情失败', e, stackTrace);
    }
  }

  /// 标记假名为已学习
  Future<void> markKanaAsLearned(int kanaId) async {
    if (state.learnedKanaIds.contains(kanaId)) return;

    try {
      // 更新本地状态
      final newLearnedIds = {...state.learnedKanaIds, kanaId};
      state = state.copyWith(learnedKanaIds: newLearnedIds);

      // 更新数据库
      await _kanaRepository.markKanaAsLearned(kanaId);

      logger.info('标记假名为已学习: kanaId=$kanaId');
    } catch (e, stackTrace) {
      logger.error('标记假名失败', e, stackTrace);
    }
  }

  /// 切换罗马音显示
  void toggleRomaji() {
    state = state.copyWith(showRomaji: !state.showRomaji);
  }

  /// 切换助记词显示
  void toggleMnemonic() {
    state = state.copyWith(showMnemonic: !state.showMnemonic);
  }

  /// 跳转到指定索引
  Future<void> goToIndex(int index) async {
    if (index < 0 || index >= state.studyQueue.length) return;
    await onPageChanged(index);
  }

  /// 下一个假名
  Future<void> nextKana() async {
    if (!state.isAtQueueEnd) {
      await onPageChanged(state.currentIndex + 1);
    }
  }

  /// 上一个假名
  Future<void> previousKana() async {
    if (state.currentIndex > 0) {
      await onPageChanged(state.currentIndex - 1);
    }
  }

  /// 重置状态
  void reset() {
    state = const KanaLearnState();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
