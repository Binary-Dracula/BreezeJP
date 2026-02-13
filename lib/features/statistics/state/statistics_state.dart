import '../../../data/models/daily_stat.dart';
import '../../../data/models/read/daily_stat_stats.dart';
import '../../../data/models/read/user_word_statistics.dart';

/// 时段类型
enum StatsPeriod { week, month, all }

/// 详细统计页面状态
class StatisticsState {
  final bool isLoading;
  final String? error;

  /// 当前选中的时段
  final StatsPeriod period;

  // ① 概览（全局，不随时段变化）
  final int masteredCount;
  final int streakDays;
  final int totalStudyTimeMs;

  // ②③ 趋势图数据（随时段变化）
  final List<DailyStat> trendData;
  final bool isMonthlyGranularity;

  // ④ 热力图（固定 90 天）
  final List<DailyStatHeatmapItem> heatmapData;

  // ⑤ 单词状态分布（全局）
  final UserWordStatistics? wordDistribution;

  // ⑥ 时段汇总（随时段变化）
  final int activeDays;
  final double avgNewLearned;
  final double avgReviewed;
  final double avgTimeMinutes;

  const StatisticsState({
    this.isLoading = false,
    this.error,
    this.period = StatsPeriod.week,
    this.masteredCount = 0,
    this.streakDays = 0,
    this.totalStudyTimeMs = 0,
    this.trendData = const [],
    this.isMonthlyGranularity = false,
    this.heatmapData = const [],
    this.wordDistribution,
    this.activeDays = 0,
    this.avgNewLearned = 0,
    this.avgReviewed = 0,
    this.avgTimeMinutes = 0,
  });

  StatisticsState copyWith({
    bool? isLoading,
    String? error,
    StatsPeriod? period,
    int? masteredCount,
    int? streakDays,
    int? totalStudyTimeMs,
    List<DailyStat>? trendData,
    bool? isMonthlyGranularity,
    List<DailyStatHeatmapItem>? heatmapData,
    UserWordStatistics? wordDistribution,
    int? activeDays,
    double? avgNewLearned,
    double? avgReviewed,
    double? avgTimeMinutes,
  }) {
    return StatisticsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      period: period ?? this.period,
      masteredCount: masteredCount ?? this.masteredCount,
      streakDays: streakDays ?? this.streakDays,
      totalStudyTimeMs: totalStudyTimeMs ?? this.totalStudyTimeMs,
      trendData: trendData ?? this.trendData,
      isMonthlyGranularity: isMonthlyGranularity ?? this.isMonthlyGranularity,
      heatmapData: heatmapData ?? this.heatmapData,
      wordDistribution: wordDistribution ?? this.wordDistribution,
      activeDays: activeDays ?? this.activeDays,
      avgNewLearned: avgNewLearned ?? this.avgNewLearned,
      avgReviewed: avgReviewed ?? this.avgReviewed,
      avgTimeMinutes: avgTimeMinutes ?? this.avgTimeMinutes,
    );
  }

  bool get hasError => error != null;

  /// 总学习时长（小时）
  double get totalStudyHours => totalStudyTimeMs / 1000.0 / 3600.0;

  /// 总学习时长（分钟）
  int get totalStudyMinutes => (totalStudyTimeMs / 1000.0 / 60.0).round();
}
