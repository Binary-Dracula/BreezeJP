import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/active_user_provider.dart';
import '../../../data/queries/daily_stat_query.dart';
import '../../../data/analytics/study_word_analytics.dart';
import '../../../data/queries/study_word_query.dart';
import '../../../data/repositories/kana_repository.dart';
import '../../../data/repositories/kana_repository_provider.dart';
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
  StudyWordAnalytics get _studyWordAnalytics =>
      ref.read(studyWordAnalyticsProvider);
  DailyStatQuery get _dailyStatQuery => ref.read(dailyStatQueryProvider);
  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  /// 加载主页数据
  Future<void> loadHomeData() async {
    try {
      logger.info('开始加载主页数据');
      state = state.copyWith(isLoading: true, error: null);

      // 1. 获取当前活跃用户
      final user = await ref.read(activeUserProvider.future);
      final userId = user.id;
      final userName = user.username;

      // 2. 获取学习统计
      final reviewCount = await _studyWordQuery.getDueReviewCount(userId);
      final kanaReviewCount = await _kanaRepository.countDueKanaReviews(userId);
      final userStats = await _studyWordAnalytics.getUserStatistics(userId);
      final newWordCount = userStats.newWords;
      final masteredWordCount = userStats.masteredWords;

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
      final todayDurationMinutes =
          ((todayStat?.totalTimeMs ?? 0) / 1000 / 60).round();

      state = state.copyWith(
        isLoading: false,
        userName: userName,
        reviewCount: reviewCount,
        newWordCount: newWordCount,
        kanaReviewCount: kanaReviewCount,
        streakDays: streakDays,
        masteredWordCount: masteredWordCount,
        todayStudyDurationMinutes: todayDurationMinutes,
        isInitialized: true,
      );

      logger.info('主页数据加载成功');
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
