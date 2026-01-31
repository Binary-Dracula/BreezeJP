import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/commands/active_user_command.dart';
import '../../../data/commands/active_user_command_provider.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/daily_stat_query.dart';
import '../../../data/queries/mastered_count_query.dart';
import '../../../data/queries/study_word_query.dart';
import '../../../data/queries/kana_query.dart';
import '../../../data/queries/kana_query_provider.dart';
import '../../../data/models/user.dart';
import '../state/home_state.dart';

/// HomeController Provider
final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

/// 主页控制器
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  StudyWordQuery get _studyWordQuery => ref.read(studyWordQueryProvider);
  DailyStatQuery get _dailyStatQuery => ref.read(dailyStatQueryProvider);
  MasteredStateQuery get _masteredCountQuery =>
      ref.read(masteredStateQueryProvider);
  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  /// 加载主页数据
  Future<void> loadHomeData() async {
    try {
      logger.debug('开始加载主页数据');
      state = state.copyWith(isLoading: true, error: null);

      // 1. 获取当前活跃用户
      final user = await _getActiveUser();
      final userId = user.id;
      final userName = user.username;

      // 2. 获取学习统计
      final reviewCount = await _studyWordQuery.getDueReviewCount(userId);
      final kanaReviewCount = await _kanaQuery.countDueKanaReviews(userId);

      // 3. 获取每日统计 (Streak & Duration)
      final streakDays = await _dailyStatQuery.calculateStreak(userId);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayStats = await _dailyStatQuery.getDailyStatsByDateRange(
        userId,
        startDate: todayStart,
        endDate: todayStart,
      );
      final todayStat = todayStats.isNotEmpty ? todayStats.first : null;
      final todayLearnedCount = todayStat?.newLearnedCount ?? 0;
      final todayReviewCount = todayStat?.reviewCount ?? 0;
      final todayDurationMinutes = ((todayStat?.totalTimeMs ?? 0) / 1000 / 60)
          .round();
      final masteredWordCount = await _masteredCountQuery.getTotalMasteredCount(
        userId,
      );

      state = state.copyWith(
        isLoading: false,
        userName: userName,
        reviewCount: reviewCount,
        newWordCount: todayLearnedCount,
        todayReviewCount: todayReviewCount,
        kanaReviewCount: kanaReviewCount,
        streakDays: streakDays,
        masteredWordCount: masteredWordCount,
        todayStudyDurationMinutes: todayDurationMinutes,
        isInitialized: true,
      );

      logger.debug('主页数据加载成功');
    } catch (e, stackTrace) {
      logger.error('加载主页数据失败', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: '加载失败: $e',
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadHomeData();
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
