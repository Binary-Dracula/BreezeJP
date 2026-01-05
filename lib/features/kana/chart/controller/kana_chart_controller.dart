import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/commands/active_user_command.dart';
import '../../../../data/commands/active_user_command_provider.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/models/user.dart';
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
  /// 当前用户 ID（从 app_state 表获取）
  int? _userId;
  Object? _activeLoadToken;

  @override
  KanaChartState build() {
    unawaited(loadKanaChart());
    return const KanaChartState();
  }

  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<int> _ensureUserId() async {
    _userId ??= (await _getActiveUser()).id;
    return _userId!;
  }

  /// 加载五十音表数据
  Future<void> loadKanaChart() async {
    final token = Object();
    _activeLoadToken = token;
    try {
      final userId = await _ensureUserId();
      if (_activeLoadToken != token) return;
      logger.info('开始加载五十音表数据');
      state = state.copyWith(isLoading: true, error: null);

      // 1. 获取所有假名类型
      final kanaTypes = await _kanaQuery.getAllKanaTypes();
      if (_activeLoadToken != token) return;

      // 2. 获取所有假名及学习状态
      final kanaLetters = await _kanaQuery.getAllKanaLettersWithState(
        userId,
      );
      if (_activeLoadToken != token) return;

      // 3. 获取统计数量
      final totalCount = await _kanaQuery.countTotalKana();
      if (_activeLoadToken != token) return;
      final masteredCount =
          await _kanaQuery.countMasteredKana(userId: userId);
      if (_activeLoadToken != token) return;

      state = state.copyWith(
        isLoading: false,
        kanaTypes: kanaTypes.map((item) => item.type).toList(),
        kanaLetters: kanaLetters,
        totalCount: totalCount,
        masteredCount: masteredCount,
      );

      logger.info('五十音表加载成功: ${kanaLetters.length}个假名, ${kanaTypes.length}个类型');
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
    unawaited(loadKanaChart());
    logger.info('切换显示模式: $newMode');
  }

  /// 设置显示模式（外部直接指定）
  void setDisplayMode(KanaDisplayMode mode) {
    if (state.displayMode == mode) return;
    state = state.copyWith(displayMode: mode);
    unawaited(loadKanaChart());
  }

  /// 设置类型筛选
  void setTypeFilter(String? type) {
    state = state.copyWith(selectedType: type);
    logger.info('设置类型筛选: ${type ?? '全部'}');
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
