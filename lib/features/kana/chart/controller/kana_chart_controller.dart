import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/queries/kana_query.dart';
import '../../../../data/queries/kana_query_provider.dart';
import '../state/kana_chart_state.dart';

/// KanaChartController Provider
final kanaChartControllerProvider =
    NotifierProvider<KanaChartController, KanaChartState>(
      KanaChartController.new,
    );

/// 五十音表控制器
class KanaChartController extends Notifier<KanaChartState> {
  Object? _activeLoadToken;

  @override
  KanaChartState build() {
    Future<void>.microtask(loadKanaChart);
    return const KanaChartState();
  }

  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  /// 加载五十音表数据
  Future<void> loadKanaChart() async {
    final token = Object();
    _activeLoadToken = token;
    try {
      logger.debug('开始加载五十音表数据');
      state = state.copyWith(isLoading: true, error: null);

      final userId = await _activeUserQuery.getActiveUserId() ?? 0;
      final results = await Future.wait<dynamic>([
        _kanaQuery.getAllKanaTypes(),
        _kanaQuery.getAllKanaLettersWithState(userId),
        _kanaQuery.countTotalKana(),
        userId > 0
            ? _kanaQuery.countMasteredKana(userId: userId)
            : Future.value(0),
      ]);
      if (_activeLoadToken != token) return;

      final kanaTypes = results[0] as List<dynamic>;
      final kanaLetters = results[1] as List<dynamic>;
      final totalCount = results[2] as int;
      final masteredCount = results[3] as int;

      state = state.copyWith(
        isLoading: false,
        kanaTypes: [for (final item in kanaTypes) item.type as String],
        kanaLetters: [for (final item in kanaLetters) item],
        totalCount: totalCount,
        masteredCount: masteredCount,
      );

      logger.debug(
        '五十音表加载成功: ${state.kanaLetters.length}个假名, ${state.kanaTypes.length}个类型',
      );
    } catch (e, stackTrace) {
      if (_activeLoadToken != token) return;
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
    logger.debug('切换显示模式: $newMode');
  }

  /// 设置显示模式（外部直接指定）
  void setDisplayMode(KanaDisplayMode mode) {
    if (state.displayMode == mode) return;
    state = state.copyWith(displayMode: mode);
  }

  /// 设置类型筛选
  void setTypeFilter(String? type) {
    state = state.copyWith(selectedType: type);
    logger.debug('设置类型筛选: ${type ?? '全部'}');
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
