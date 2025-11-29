import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/kana_repository.dart';
import '../../../data/repositories/kana_repository_provider.dart';
import '../state/kana_chart_state.dart';

/// KanaChartController Provider
final kanaChartControllerProvider =
    NotifierProvider<KanaChartController, KanaChartState>(
      KanaChartController.new,
    );

/// 五十音表控制器
class KanaChartController extends Notifier<KanaChartState> {
  @override
  KanaChartState build() => const KanaChartState();

  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  /// 加载五十音表数据
  Future<void> loadKanaChart() async {
    try {
      logger.info('开始加载五十音表数据');
      state = state.copyWith(isLoading: true, error: null);

      // 1. 获取所有假名类型
      final kanaTypes = await _kanaRepository.getAllKanaTypes();

      // 2. 获取所有假名及学习状态
      final kanaLetters = await _kanaRepository.getAllKanaLettersWithState();

      // 3. 获取学习统计
      final stats = await _kanaRepository.getKanaLearningStats();

      state = state.copyWith(
        isLoading: false,
        kanaTypes: kanaTypes,
        kanaLetters: kanaLetters,
        totalCount: stats['total'] ?? 0,
        learnedCount: stats['learned'] ?? 0,
      );

      logger.info('五十音表加载成功: ${kanaLetters.length}个假名, ${kanaTypes.length}个类型');
    } catch (e, stackTrace) {
      logger.error('加载五十音表失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 切换显示模式 (平假名/片假名)
  void toggleDisplayMode() {
    final newMode = state.displayMode == KanaDisplayMode.hiragana
        ? KanaDisplayMode.katakana
        : KanaDisplayMode.hiragana;
    state = state.copyWith(displayMode: newMode);
    logger.info('切换显示模式: $newMode');
  }

  /// 设置显示模式
  void setDisplayMode(KanaDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  /// 设置类型筛选
  void setTypeFilter(String? type) {
    state = state.copyWith(selectedType: type);
    logger.info('设置类型筛选: ${type ?? '全部'}');
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadKanaChart();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
