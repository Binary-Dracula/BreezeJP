import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/queries/active_user_query.dart';
import '../../../data/queries/active_user_query_provider.dart';
import '../../../data/queries/daily_stat_query.dart';
import '../../../data/queries/mastered_count_query.dart';
import '../../../data/queries/statistics_query.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/read/daily_stat_stats.dart';
import '../state/statistics_state.dart';

/// StatisticsController Provider
final statisticsControllerProvider =
    NotifierProvider<StatisticsController, StatisticsState>(
      StatisticsController.new,
    );

/// 详细统计页控制器
class StatisticsController extends Notifier<StatisticsState> {
  @override
  StatisticsState build() => const StatisticsState();

  DailyStatQuery get _dailyStatQuery => ref.read(dailyStatQueryProvider);
  MasteredStateQuery get _masteredCountQuery =>
      ref.read(masteredStateQueryProvider);
  StatisticsQuery get _statisticsQuery => ref.read(statisticsQueryProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  /// 加载全部数据
  Future<void> loadData() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final user = await _activeUserQuery.getActiveUser();
      if (user == null) {
        state = state.copyWith(isLoading: false, error: '未找到活跃用户');
        return;
      }
      final userId = user.id;

      // 并行加载全局数据
      final results = await Future.wait([
        _masteredCountQuery.getTotalMasteredCount(userId),
        _dailyStatQuery.calculateStreak(userId),
        _statisticsQuery.getTotalStudyTimeMs(userId),
        _dailyStatQuery.getHeatmapData(userId, days: 365),
        _statisticsQuery.getWordStatusDistribution(userId),
      ]);

      final masteredCount = results[0] as int;
      final streakDays = results[1] as int;
      final totalStudyTimeMs = results[2] as int;
      final heatmapData = results[3] as List<DailyStatHeatmapItem>;
      final wordDistribution = results[4] as dynamic;

      state = state.copyWith(
        masteredCount: masteredCount,
        streakDays: streakDays,
        totalStudyTimeMs: totalStudyTimeMs,
        heatmapData: heatmapData,
        wordDistribution: wordDistribution,
      );

      // 加载时段数据
      await _loadPeriodData(userId, state.period);

      state = state.copyWith(isLoading: false);
      logger.debug('统计数据加载完成');
    } catch (e, stackTrace) {
      logger.error('加载统计数据失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 切换时段
  Future<void> switchPeriod(StatsPeriod period) async {
    if (state.period == period) return;
    state = state.copyWith(period: period);

    try {
      final user = await _activeUserQuery.getActiveUser();
      if (user == null) return;
      await _loadPeriodData(user.id, period);
    } catch (e, stackTrace) {
      logger.error('切换时段失败', e, stackTrace);
    }
  }

  /// 加载时段相关数据（趋势 + 汇总）
  Future<void> _loadPeriodData(int userId, StatsPeriod period) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late DateTime startDate;
    late DateTime endDate;
    switch (period) {
      case StatsPeriod.week:
        // 本周一 ~ 本周日（完整 7 天）
        startDate = today.subtract(Duration(days: today.weekday - 1));
        endDate = startDate.add(const Duration(days: 6));
        break;
      case StatsPeriod.month:
        // 本月 1 日 ~ 本月最后一天（完整月）
        startDate = DateTime(today.year, today.month, 1);
        endDate = DateTime(today.year, today.month + 1, 0); // 月末
        break;
      case StatsPeriod.all:
        startDate = today.subtract(const Duration(days: 365));
        endDate = today;
        break;
    }

    // 获取已有数据（只到今天为止有实际数据）
    final fetchEnd = endDate.isAfter(today) ? today : endDate;
    final rawData = await _dailyStatQuery.getDailyStatsByDateRange(
      userId,
      startDate: startDate,
      endDate: fetchEnd,
    );

    late List<DailyStat> trendData;
    final bool isMonthly = period == StatsPeriod.all;

    if (isMonthly) {
      // ─── "全部"模式：按月聚合 ───
      trendData = _aggregateByMonth(rawData, userId, startDate, today);
    } else {
      // ─── 本周/本月：按天填充 ───
      final dataByDate = <String, DailyStat>{};
      for (final stat in rawData) {
        dataByDate[stat.dateString] = stat;
      }
      trendData = <DailyStat>[];
      var cursor = startDate;
      while (!cursor.isAfter(endDate)) {
        final dateStr = _formatDate(cursor);
        final existing = dataByDate[dateStr];
        if (existing != null) {
          trendData.add(existing);
        } else {
          trendData.add(DailyStat(id: 0, userId: userId, date: cursor));
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    // 计算汇总（仅统计到今天为止的活跃天）
    final pastData = rawData.where((s) => !s.date.isAfter(today));
    final activeDays = pastData.where((s) => s.hasActivity).length;
    final totalLearned = pastData.fold<int>(
      0,
      (sum, s) => sum + s.newLearnedCount,
    );
    final totalReviewed = pastData.fold<int>(
      0,
      (sum, s) => sum + s.reviewCount,
    );
    final totalTimeMs = pastData.fold<int>(0, (sum, s) => sum + s.totalTimeMs);

    final avgNewLearned = activeDays > 0 ? totalLearned / activeDays : 0.0;
    final avgReviewed = activeDays > 0 ? totalReviewed / activeDays : 0.0;
    final avgTimeMinutes = activeDays > 0
        ? totalTimeMs / 1000.0 / 60.0 / activeDays
        : 0.0;

    state = state.copyWith(
      trendData: trendData,
      isMonthlyGranularity: isMonthly,
      activeDays: activeDays,
      avgNewLearned: avgNewLearned,
      avgReviewed: avgReviewed,
      avgTimeMinutes: avgTimeMinutes,
    );
  }

  /// 将每日数据按月聚合，每月产出一个 DailyStat（date 为该月 1 日）
  List<DailyStat> _aggregateByMonth(
    List<DailyStat> rawData,
    int userId,
    DateTime startDate,
    DateTime today,
  ) {
    // 数据按 year-month 分桶
    final buckets = <String, List<DailyStat>>{};
    for (final stat in rawData) {
      final key = '${stat.date.year}-${stat.date.month}';
      (buckets[key] ??= []).add(stat);
    }

    // 生成从 startDate 到 today 的所有月份
    final result = <DailyStat>[];
    var cursor = DateTime(startDate.year, startDate.month, 1);
    final lastMonth = DateTime(today.year, today.month, 1);

    while (!cursor.isAfter(lastMonth)) {
      final key = '${cursor.year}-${cursor.month}';
      final monthData = buckets[key];

      if (monthData != null && monthData.isNotEmpty) {
        final totalReview = monthData.fold<int>(0, (s, d) => s + d.reviewCount);
        final totalNew = monthData.fold<int>(
          0,
          (s, d) => s + d.newLearnedCount,
        );
        final totalTime = monthData.fold<int>(0, (s, d) => s + d.totalTimeMs);
        result.add(
          DailyStat(
            id: 0,
            userId: userId,
            date: cursor,
            reviewCount: totalReview,
            newLearnedCount: totalNew,
            totalTimeMs: totalTime,
          ),
        );
      } else {
        result.add(DailyStat(id: 0, userId: userId, date: cursor));
      }

      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return result;
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
