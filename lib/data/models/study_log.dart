/// 学习日志模型
/// 记录用户的所有学习事件和历史
class StudyLog {
  final int id;
  final int userId;
  final int wordId;
  final LogType logType;
  final ReviewRating? rating;
  final double? intervalAfter;
  final double? easeFactorAfter;
  final DateTime? nextReviewAtAfter;
  final int durationMs;
  final DateTime createdAt;

  StudyLog({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.logType,
    this.rating,
    this.intervalAfter,
    this.easeFactorAfter,
    this.nextReviewAtAfter,
    this.durationMs = 0,
    required this.createdAt,
  });

  /// 从数据库 Map 创建实例
  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      wordId: map['word_id'] as int,
      logType: LogType.fromValue(map['log_type'] as int),
      rating: map['rating'] != null
          ? ReviewRating.fromValue(map['rating'] as int)
          : null,
      intervalAfter: (map['interval_after'] as num?)?.toDouble(),
      easeFactorAfter: (map['ease_factor_after'] as num?)?.toDouble(),
      nextReviewAtAfter: map['next_review_at_after'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['next_review_at_after'] as int) * 1000,
            )
          : null,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'word_id': wordId,
      'log_type': logType.value,
      'rating': rating?.value,
      'interval_after': intervalAfter,
      'ease_factor_after': easeFactorAfter,
      'next_review_at_after': nextReviewAtAfter != null
          ? nextReviewAtAfter!.millisecondsSinceEpoch ~/ 1000
          : null,
      'duration_ms': durationMs,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// 复制并修改部分字段
  StudyLog copyWith({
    int? id,
    int? userId,
    int? wordId,
    LogType? logType,
    ReviewRating? rating,
    double? intervalAfter,
    double? easeFactorAfter,
    DateTime? nextReviewAtAfter,
    int? durationMs,
    DateTime? createdAt,
  }) {
    return StudyLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordId: wordId ?? this.wordId,
      logType: logType ?? this.logType,
      rating: rating ?? this.rating,
      intervalAfter: intervalAfter ?? this.intervalAfter,
      easeFactorAfter: easeFactorAfter ?? this.easeFactorAfter,
      nextReviewAtAfter: nextReviewAtAfter ?? this.nextReviewAtAfter,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 是否为复习事件
  bool get isReview => logType == LogType.review;

  /// 是否为初次学习
  bool get isFirstLearn => logType == LogType.firstLearn;

  /// 学习时长（秒）
  double get durationSeconds => durationMs / 1000.0;

  /// 学习时长（分钟）
  double get durationMinutes => durationMs / 1000.0 / 60.0;
}

/// 日志事件类型
enum LogType {
  /// 初次学习
  firstLearn(1),

  /// 复习
  review(2),

  /// 手动标记已掌握
  markMastered(3),

  /// 手动忽略
  markIgnored(4),

  /// 手动恢复/重置
  reset(5),

  /// 自动计划生成（可选）
  autoSchedule(6);

  const LogType(this.value);

  final int value;

  /// 从数据库值创建枚举
  static LogType fromValue(int value) {
    return LogType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LogType.review,
    );
  }

  /// 获取类型描述
  String get description {
    switch (this) {
      case LogType.firstLearn:
        return '初次学习';
      case LogType.review:
        return '复习';
      case LogType.markMastered:
        return '标记已掌握';
      case LogType.markIgnored:
        return '标记忽略';
      case LogType.reset:
        return '重置进度';
      case LogType.autoSchedule:
        return '自动计划';
    }
  }
}

/// 复习评分
enum ReviewRating {
  /// 完全忘记
  again(1),

  /// 困难，勉强记起
  hard(2),

  /// 一般，正常记起
  good(3),

  /// 简单，轻松记起
  easy(4);

  const ReviewRating(this.value);

  final int value;

  /// 从数据库值创建枚举
  static ReviewRating fromValue(int value) {
    return ReviewRating.values.firstWhere(
      (rating) => rating.value == value,
      orElse: () => ReviewRating.good,
    );
  }

  /// 获取评分描述
  String get description {
    switch (this) {
      case ReviewRating.again:
        return '忘记';
      case ReviewRating.hard:
        return '困难';
      case ReviewRating.good:
        return '一般';
      case ReviewRating.easy:
        return '简单';
    }
  }

  /// 获取评分颜色（用于 UI）
  String get colorHex {
    switch (this) {
      case ReviewRating.again:
        return '#F44336'; // 红色
      case ReviewRating.hard:
        return '#FF9800'; // 橙色
      case ReviewRating.good:
        return '#4CAF50'; // 绿色
      case ReviewRating.easy:
        return '#2196F3'; // 蓝色
    }
  }

  /// 是否答对（用于 SRS 计算）
  bool get isCorrect => this != ReviewRating.again;
}
