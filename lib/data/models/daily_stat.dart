/// 每日学习统计模型
/// 汇总用户每天的学习数据，用于报表和趋势分析
class DailyStat {
  final int id;
  final int userId;
  final DateTime date;
  final int totalStudyTimeMs; // 毫秒
  final int learnedWordsCount;
  final int reviewedWordsCount;
  final int masteredWordsCount;
  final int failedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyStat({
    required this.id,
    required this.userId,
    required this.date,
    this.totalStudyTimeMs = 0,
    this.learnedWordsCount = 0,
    this.reviewedWordsCount = 0,
    this.masteredWordsCount = 0,
    this.failedCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建实例
  factory DailyStat.fromMap(Map<String, dynamic> map) {
    return DailyStat(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      date: DateTime.parse(map['date'] as String),
      totalStudyTimeMs: map['total_study_time_ms'] as int? ?? 0,
      learnedWordsCount: map['learned_words_count'] as int? ?? 0,
      reviewedWordsCount: map['reviewed_words_count'] as int? ?? 0,
      masteredWordsCount: map['mastered_words_count'] as int? ?? 0,
      failedCount: map['failed_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  /// 转换为数据库 Map（用于插入，不包含 id）
  Map<String, dynamic> toMapForInsert() {
    return {
      'user_id': userId,
      'date': _formatDate(date),
      'total_study_time_ms': totalStudyTimeMs,
      'learned_words_count': learnedWordsCount,
      'reviewed_words_count': reviewedWordsCount,
      'mastered_words_count': masteredWordsCount,
      'failed_count': failedCount,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
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
    int? totalStudyTimeMs,
    int? learnedWordsCount,
    int? reviewedWordsCount,
    int? masteredWordsCount,
    int? failedCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyStat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      totalStudyTimeMs: totalStudyTimeMs ?? this.totalStudyTimeMs,
      learnedWordsCount: learnedWordsCount ?? this.learnedWordsCount,
      reviewedWordsCount: reviewedWordsCount ?? this.reviewedWordsCount,
      masteredWordsCount: masteredWordsCount ?? this.masteredWordsCount,
      failedCount: failedCount ?? this.failedCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
  double get totalStudyMinutes => totalStudyTimeMs / 1000.0 / 60.0;

  /// 学习时长（小时）
  double get totalStudyHours => totalStudyTimeMs / 1000.0 / 3600.0;

  /// 总学习单词数（新学 + 复习）
  int get totalWordsCount => learnedWordsCount + reviewedWordsCount;

  /// 是否有学习活动
  bool get hasActivity => totalWordsCount > 0 || totalStudyTimeMs > 0;

  /// 正确率（如果有复习的话）
  double? get accuracy {
    if (reviewedWordsCount == 0) return null;
    final correctCount = reviewedWordsCount - failedCount;
    return correctCount / reviewedWordsCount;
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
    return totalStudyTimeMs / 1000.0 / totalWordsCount;
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
      totalStudyTimeMs: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 从日期创建统计
  static DailyStat createForDate(int userId, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();

    return DailyStat(
      id: 0,
      userId: userId,
      date: dateOnly,
      totalStudyTimeMs: 0,
      createdAt: now,
      updatedAt: now,
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
