/// 每日统计汇总（周/月）
class DailyStatSummary {
  final int? totalTime;
  final int? totalLearned;
  final int? totalReviewed;
  final int? totalMastered;
  final double? avgTimePerDay;
  final int? activeDays;

  const DailyStatSummary({
    this.totalTime,
    this.totalLearned,
    this.totalReviewed,
    this.totalMastered,
    this.avgTimePerDay,
    this.activeDays,
  });

  factory DailyStatSummary.fromMap(Map<String, dynamic> map) {
    return DailyStatSummary(
      totalTime: (map['total_time'] as num?)?.toInt(),
      totalLearned: (map['total_learned'] as num?)?.toInt(),
      totalReviewed: (map['total_reviewed'] as num?)?.toInt(),
      totalMastered: (map['total_mastered'] as num?)?.toInt(),
      avgTimePerDay: (map['avg_time_per_day'] as num?)?.toDouble(),
      activeDays: (map['active_days'] as num?)?.toInt(),
    );
  }
}

/// 学习热力图项
class DailyStatHeatmapItem {
  final String date;
  final int count;

  const DailyStatHeatmapItem({required this.date, required this.count});
}
