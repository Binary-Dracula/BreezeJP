import '../study_log.dart';

/// 学习日志的每日统计项
class StudyLogDailyStatistics {
  final String date;
  final int totalReviews;
  final int newLearned;
  final int reviews;
  final int totalDurationMs;
  final double avgDurationMs;

  const StudyLogDailyStatistics({
    required this.date,
    required this.totalReviews,
    required this.newLearned,
    required this.reviews,
    required this.totalDurationMs,
    required this.avgDurationMs,
  });

  factory StudyLogDailyStatistics.fromMap(Map<String, dynamic> map) {
    return StudyLogDailyStatistics(
      date: map['date'] as String,
      totalReviews: (map['total_reviews'] as int?) ?? 0,
      newLearned: (map['new_learned'] as int?) ?? 0,
      reviews: (map['reviews'] as int?) ?? 0,
      totalDurationMs: (map['total_duration_ms'] as int?) ?? 0,
      avgDurationMs: (map['avg_duration_ms'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 复习评分分布统计项
class StudyLogRatingCount {
  final ReviewRating rating;
  final int count;

  const StudyLogRatingCount({required this.rating, required this.count});
}

/// 学习时长统计
class StudyLogTimeStatistics {
  final int? totalMs;
  final int? totalSessions;
  final double? avgMs;
  final int? maxMs;
  final int? minMs;

  const StudyLogTimeStatistics({
    this.totalMs,
    this.totalSessions,
    this.avgMs,
    this.maxMs,
    this.minMs,
  });

  factory StudyLogTimeStatistics.fromMap(Map<String, dynamic> map) {
    return StudyLogTimeStatistics(
      totalMs: (map['total_ms'] as num?)?.toInt(),
      totalSessions: (map['total_sessions'] as num?)?.toInt(),
      avgMs: (map['avg_ms'] as num?)?.toDouble(),
      maxMs: (map['max_ms'] as num?)?.toInt(),
      minMs: (map['min_ms'] as num?)?.toInt(),
    );
  }
}

/// 学习热力图项
class StudyLogHeatmapItem {
  final String date;
  final int count;

  const StudyLogHeatmapItem({required this.date, required this.count});
}

/// 总体学习统计
class StudyLogOverallStatistics {
  final int? totalLogs;
  final int? uniqueWords;
  final int? firstLearns;
  final int? reviews;
  final int? totalDurationMs;
  final double? avgDurationMs;
  final int? firstLogAt;
  final int? lastLogAt;

  const StudyLogOverallStatistics({
    this.totalLogs,
    this.uniqueWords,
    this.firstLearns,
    this.reviews,
    this.totalDurationMs,
    this.avgDurationMs,
    this.firstLogAt,
    this.lastLogAt,
  });

  factory StudyLogOverallStatistics.fromMap(Map<String, dynamic> map) {
    return StudyLogOverallStatistics(
      totalLogs: (map['total_logs'] as num?)?.toInt(),
      uniqueWords: (map['unique_words'] as num?)?.toInt(),
      firstLearns: (map['first_learns'] as num?)?.toInt(),
      reviews: (map['reviews'] as num?)?.toInt(),
      totalDurationMs: (map['total_duration_ms'] as num?)?.toInt(),
      avgDurationMs: (map['avg_duration_ms'] as num?)?.toDouble(),
      firstLogAt: (map['first_log_at'] as num?)?.toInt(),
      lastLogAt: (map['last_log_at'] as num?)?.toInt(),
    );
  }
}
