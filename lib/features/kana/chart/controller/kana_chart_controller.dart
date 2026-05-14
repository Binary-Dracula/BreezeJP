import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/constants/learning_status.dart';
import '../../../../core/providers/kana_state_cache_provider.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/queries/active_user_query.dart';
import '../../../../data/queries/active_user_query_provider.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/models/read/kana_detail.dart';
import '../../../../data/queries/kana_remote_query.dart';
import '../../../../data/queries/kana_remote_query_provider.dart';
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
  KanaRemoteQuery get _kanaRemoteQuery => ref.read(kanaRemoteQueryProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);
  KanaStateCacheNotifier get _kanaStateCache =>
      ref.read(kanaStateCacheProvider.notifier);
  bool get _isLoggedIn => ref.read(isLoggedInProvider);

  /// 加载五十音表数据
  Future<void> loadKanaChart() async {
    final token = Object();
    _activeLoadToken = token;
    try {
      logger.debug('开始加载五十音表数据');
      state = state.copyWith(isLoading: true, error: null);

      if (!_isLoggedIn) {
        _kanaStateCache.clear();
        state = state.copyWith(
          isLoading: false,
          error: '请登录后查看五十音学习进度',
          kanaLetters: const [],
          kanaTypes: const [],
          selectedType: null,
          totalCount: 0,
          masteredCount: 0,
        );
        return;
      }

      final userId = await _activeUserQuery.getActiveUserId() ?? 0;
      if (userId <= 0) {
        _kanaStateCache.clear();
        state = state.copyWith(
          isLoading: false,
          error: '未找到当前用户，请重新登录后重试',
          kanaLetters: const [],
          kanaTypes: const [],
          selectedType: null,
          totalCount: 0,
          masteredCount: 0,
        );
        return;
      }

      final results = await Future.wait<dynamic>([
        _kanaQuery.getAllKanaTypes(),
        _kanaQuery.getAllKanaLetters(),
        _kanaQuery.countTotalKana(),
        _kanaRemoteQuery.fetchKanaStates(),
      ]);
      if (_activeLoadToken != token) return;

      final kanaTypes = results[0] as List<dynamic>;
      final kanaLetters = List<KanaLetter>.from(results[1] as List<dynamic>)
        ..sort(
          (left, right) => (left.displayOrder ?? 1 << 30).compareTo(
            right.displayOrder ?? 1 << 30,
          ),
        );
      final totalCount = results[2] as int;
      final remoteStates = results[3] as List<RemoteKanaState>;
      final learningStates = remoteStates
          .map((remoteState) => remoteState.toLearningState(userId: userId))
          .toList();
      _kanaStateCache.replaceStates(learningStates);
      final stateByKanaId = {
        for (final learningState in learningStates)
          learningState.kanaId: learningState,
      };
      final lettersWithState = kanaLetters
          .map(
            (letter) => KanaLetterWithState(
              letter: letter,
              learningState: stateByKanaId[letter.id],
            ),
          )
          .toList();
      final masteredCount = stateByKanaId.values
          .where(
            (learningState) =>
                learningState.learningStatus == LearningStatus.mastered,
          )
          .length;

      state = state.copyWith(
        isLoading: false,
        kanaTypes: [for (final item in kanaTypes) item.type as String],
        kanaLetters: lettersWithState,
        totalCount: totalCount,
        masteredCount: masteredCount,
      );

      logger.debug(
        '五十音表远端状态加载成功: ${state.kanaLetters.length}个假名, ${state.kanaTypes.length}个类型',
      );
      return;
    } catch (e, stackTrace) {
      if (_activeLoadToken != token) return;
      _kanaStateCache.clear();
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
