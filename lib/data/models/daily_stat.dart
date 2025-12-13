/// 每日学习统计模型
/// 汇总用户每天的学习数据，用于报表和趋势分析
class DailyStat {
  final int id;
  final int userId;
  final DateTime date;
  final int reviewCount;
  final int uniqueKanaReviewedCount;
  final int newLearnedCount;
  final double ratingAvg;
  final double wrongRatio;
  final double newIntervalAvg;
  final int totalTimeMs;
  final int? firstReviewAt;
  final int? lastReviewAt;
  final int algorithm;
  final double? learningQualityScore;

  DailyStat({
    required this.id,
    required this.userId,
    required this.date,
    this.reviewCount = 0,
    this.uniqueKanaReviewedCount = 0,
    this.newLearnedCount = 0,
    this.ratingAvg = 0,
    this.wrongRatio = 0,
    this.newIntervalAvg = 0,
    this.totalTimeMs = 0,
    this.firstReviewAt,
    this.lastReviewAt,
    this.algorithm = 1,
    this.learningQualityScore,
  });

  /// 从数据库 Map 创建实例（字段顺序与 daily_stats 表保持一致）
  factory DailyStat.fromMap(Map<String, dynamic> map) {
    return DailyStat(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      date: DateTime.parse(map['date'] as String),
      reviewCount: map['review_count'] as int? ?? 0,
      uniqueKanaReviewedCount: map['unique_kana_reviewed_count'] as int? ?? 0,
      newLearnedCount: map['new_learned_count'] as int? ?? 0,
      ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
      wrongRatio: (map['wrong_ratio'] as num?)?.toDouble() ?? 0,
      newIntervalAvg: (map['new_interval_avg'] as num?)?.toDouble() ?? 0,
      totalTimeMs: map['total_time_ms'] as int? ?? 0,
      firstReviewAt: map['first_review_at'] as int?,
      lastReviewAt: map['last_review_at'] as int?,
      algorithm: map['algorithm'] as int? ?? 1,
      learningQualityScore: (map['learning_quality_score'] as num?)?.toDouble(),
    );
  }

  /// 转换为数据库 Map（用于插入，不包含 id）
  Map<String, dynamic> toMapForInsert() {
    return {
      'user_id': userId,
      'date': _formatDate(date),
      'review_count': reviewCount,
      'unique_kana_reviewed_count': uniqueKanaReviewedCount,
      'new_learned_count': newLearnedCount,
      'rating_avg': ratingAvg,
      'wrong_ratio': wrongRatio,
      'new_interval_avg': newIntervalAvg,
      'total_time_ms': totalTimeMs,
      'first_review_at': firstReviewAt,
      'last_review_at': lastReviewAt,
      'algorithm': algorithm,
      'learning_quality_score': learningQualityScore,
    };
  }

  /// 转换为数据库 Map（用于更新，包含 id）
  Map<String, dynamic> toMap() {
    final map = toMapForInsert();
    map['id'] = id;
    return map;
  }

  /// 复制并修改部分字段
  DailyStat copyWith({
    int? id,
    int? userId,
    DateTime? date,
    int? reviewCount,
    int? uniqueKanaReviewedCount,
    int? newLearnedCount,
    double? ratingAvg,
    double? wrongRatio,
    double? newIntervalAvg,
    int? totalTimeMs,
    int? firstReviewAt,
    int? lastReviewAt,
    int? algorithm,
    double? learningQualityScore,
  }) {
    return DailyStat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      reviewCount: reviewCount ?? this.reviewCount,
      uniqueKanaReviewedCount:
          uniqueKanaReviewedCount ?? this.uniqueKanaReviewedCount,
      newLearnedCount: newLearnedCount ?? this.newLearnedCount,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      wrongRatio: wrongRatio ?? this.wrongRatio,
      newIntervalAvg: newIntervalAvg ?? this.newIntervalAvg,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
      firstReviewAt: firstReviewAt ?? this.firstReviewAt,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      algorithm: algorithm ?? this.algorithm,
      learningQualityScore: learningQualityScore ?? this.learningQualityScore,
    );
  }

  /// 格式化日期为 YYYY-MM-DD
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取日期字符串（YYYY-MM-DD）
  String get dateString => _formatDate(date);

  /// 学习时长（分钟）
  double get totalStudyMinutes => totalTimeMs / 1000.0 / 60.0;

  /// 学习时长（小时）
  double get totalStudyHours => totalTimeMs / 1000.0 / 3600.0;

  /// 总学习单词数（新学 + 复习）
  int get totalWordsCount => newLearnedCount + reviewCount;

  /// 是否有学习活动
  bool get hasActivity => totalWordsCount > 0 || totalTimeMs > 0;

  /// 正确率（如果有复习的话）
  double? get accuracy {
    if (reviewCount == 0) return null;
    final correctCount = reviewCount * (1 - wrongRatio);
    return correctCount / reviewCount;
  }

  /// 正确率百分比
  String get accuracyPercentage {
    final acc = accuracy;
    if (acc == null) return 'N/A';
    return '${(acc * 100).toStringAsFixed(1)}%';
  }

  /// 平均每个单词的学习时间（秒）
  double? get avgTimePerWord {
    if (totalWordsCount == 0) return null;
    return totalTimeMs / 1000.0 / totalWordsCount;
  }

  /// 学习效率评级（基于时间和数量）
  StudyEfficiency get efficiency {
    if (!hasActivity) return StudyEfficiency.none;

    final avgTime = avgTimePerWord;
    if (avgTime == null) return StudyEfficiency.none;

    // 平均每个单词 5-15 秒为高效
    if (avgTime >= 5 && avgTime <= 15) return StudyEfficiency.high;
    // 15-30 秒为中等
    if (avgTime > 15 && avgTime <= 30) return StudyEfficiency.medium;
    // 其他为低效
    return StudyEfficiency.low;
  }

  /// 创建今日统计（初始值为0）
  static DailyStat createToday(int userId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return DailyStat(
      id: 0,
      userId: userId,
      date: today,
      totalTimeMs: 0,
      newLearnedCount: 0,
      reviewCount: 0,
      uniqueKanaReviewedCount: 0,
      ratingAvg: 0,
      wrongRatio: 0,
      newIntervalAvg: 0,
      learningQualityScore: null,
      firstReviewAt: null,
      lastReviewAt: null,
      algorithm: 1,
    );
  }

  /// 从日期创建统计
  static DailyStat createForDate(int userId, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    return DailyStat(
      id: 0,
      userId: userId,
      date: dateOnly,
      totalTimeMs: 0,
      newLearnedCount: 0,
      reviewCount: 0,
      uniqueKanaReviewedCount: 0,
      ratingAvg: 0,
      wrongRatio: 0,
      newIntervalAvg: 0,
      learningQualityScore: null,
      firstReviewAt: null,
      lastReviewAt: null,
      algorithm: 1,
    );
  }
}

/// 学习效率评级
enum StudyEfficiency {
  /// 无学习活动
  none,

  /// 低效（过快或过慢）
  low,

  /// 中等
  medium,

  /// 高效
  high;

  /// 获取描述
  String get description {
    switch (this) {
      case StudyEfficiency.none:
        return '无活动';
      case StudyEfficiency.low:
        return '低效';
      case StudyEfficiency.medium:
        return '中等';
      case StudyEfficiency.high:
        return '高效';
    }
  }

  /// 获取颜色（用于 UI）
  String get colorHex {
    switch (this) {
      case StudyEfficiency.none:
        return '#9E9E9E'; // 灰色
      case StudyEfficiency.low:
        return '#FF9800'; // 橙色
      case StudyEfficiency.medium:
        return '#2196F3'; // 蓝色
      case StudyEfficiency.high:
        return '#4CAF50'; // 绿色
    }
  }
}
