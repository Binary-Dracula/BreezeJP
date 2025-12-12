import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/active_user_provider.dart';
import '../../../data/repositories/daily_stat_repository.dart';
import '../../../data/repositories/daily_stat_repository_provider.dart';
import '../../../data/repositories/study_word_repository.dart';
import '../../../data/repositories/study_word_repository_provider.dart';
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

  StudyWordRepository get _studyWordRepository =>
      ref.read(studyWordRepositoryProvider);
  DailyStatRepository get _dailyStatRepository =>
      ref.read(dailyStatRepositoryProvider);
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
      final reviewCount = await _studyWordRepository.getDueReviewCount(userId);
      final kanaReviewCount = await _kanaRepository.countDueKanaReviews(userId);
      final userStats = await _studyWordRepository.getUserStatistics(userId);
      final newWordCount = (userStats['new_words'] as int?) ?? 0;
      final masteredWordCount = (userStats['mastered_words'] as int?) ?? 0;

      // 3. 获取每日统计 (Streak & Duration)
      final streakDays = await _dailyStatRepository.calculateStreak(userId);
      final todayStat = await _dailyStatRepository.getOrCreateTodayStat(userId);
      final todayDurationMinutes = (todayStat.totalStudyTimeMs / 1000 / 60)
          .round();

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
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
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
