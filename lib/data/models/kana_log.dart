/// 五十音学习日志类型枚举
enum KanaLogType {
  firstLearn, // 1 - 初学
  review, // 2 - 复习
  mastered, // 3 - 掌握
  quiz, // 4 - 测验
  forgot, // 5 - 忘记/失败
  ignored, // 6 - 忽略
}

/// 五十音学习日志模型
/// 记录用户的五十音学习行为，与 study_logs 表结构保持一致
class KanaLog {
  final int id;
  final int userId;
  final int kanaId;

  /// 日志类型：1=初学, 2=复习, 3=掌握, 4=测验, 5=忘记/失败, 6=忽略
  final KanaLogType logType;

  /// 评分：1=Again, 2=Good, 3=Easy
  final int? rating;

  /// 算法：1=SM-2, 2=FSRS
  final int algorithm;

  /// [SM-2] 操作后复习间隔 (天)
  final double? intervalAfter;

  /// 操作后下次复习时间戳
  final int? nextReviewAtAfter;

  /// [SM-2] 操作后难度因子
  final double? easeFactorAfter;

  /// [FSRS] 操作后记忆稳定性
  final double? fsrsStabilityAfter;

  /// [FSRS] 操作后记忆难度
  final double? fsrsDifficultyAfter;

  /// 单次学习耗时 (毫秒)
  final int durationMs;

  /// 创建时间 (Unix 时间戳)
  final int createdAt;

  /// 题型标记（recall/audio/switchMode），可选
  final String? questionType;

  KanaLog({
    required this.id,
    required this.userId,
    required this.kanaId,
    required this.logType,
    this.rating,
    this.algorithm = 1,
    this.intervalAfter,
    this.nextReviewAtAfter,
    this.easeFactorAfter,
    this.fsrsStabilityAfter,
    this.fsrsDifficultyAfter,
    this.durationMs = 0,
    this.questionType,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// 是否为测验记录
  bool get isQuiz => logType == KanaLogType.quiz;

  /// 是否为复习记录
  bool get isReview => logType == KanaLogType.review;

  /// 是否为初学记录
  bool get isFirstLearn => logType == KanaLogType.firstLearn;

  factory KanaLog.fromMap(Map<String, dynamic> map) {
    final logTypeValue = (map['log_type'] as int? ?? 1)
        .clamp(1, KanaLogType.values.length)
        .toInt();
    return KanaLog(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      kanaId: map['kana_id'] as int,
      logType: KanaLogType.values[logTypeValue - 1],
      rating: map['rating'] as int?,
      algorithm: map['algorithm'] as int? ?? 1,
      intervalAfter: (map['interval_after'] as num?)?.toDouble(),
      nextReviewAtAfter: map['next_review_at_after'] as int?,
      easeFactorAfter: (map['ease_factor_after'] as num?)?.toDouble(),
      fsrsStabilityAfter: (map['fsrs_stability_after'] as num?)?.toDouble(),
      fsrsDifficultyAfter: (map['fsrs_difficulty_after'] as num?)?.toDouble(),
      durationMs: map['duration_ms'] as int? ?? 0,
      questionType: map['question_type'] as String?,
      createdAt: map['created_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kana_id': kanaId,
      'log_type': logType.index + 1,
      'rating': rating,
      'algorithm': algorithm,
      'interval_after': intervalAfter,
      'next_review_at_after': nextReviewAtAfter,
      'ease_factor_after': easeFactorAfter,
      'fsrs_stability_after': fsrsStabilityAfter,
      'fsrs_difficulty_after': fsrsDifficultyAfter,
      'duration_ms': durationMs,
      'question_type': questionType,
      'created_at': createdAt,
    };
  }

  /// 用于插入的 Map（不包含 id）
  Map<String, dynamic> toInsertMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  KanaLog copyWith({
    int? id,
    int? userId,
    int? kanaId,
    KanaLogType? logType,
    int? rating,
    int? algorithm,
    double? intervalAfter,
    int? nextReviewAtAfter,
    double? easeFactorAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    int? durationMs,
    int? createdAt,
    String? questionType,
  }) {
    return KanaLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kanaId: kanaId ?? this.kanaId,
      logType: logType ?? this.logType,
      rating: rating ?? this.rating,
      algorithm: algorithm ?? this.algorithm,
      intervalAfter: intervalAfter ?? this.intervalAfter,
      nextReviewAtAfter: nextReviewAtAfter ?? this.nextReviewAtAfter,
      easeFactorAfter: easeFactorAfter ?? this.easeFactorAfter,
      fsrsStabilityAfter: fsrsStabilityAfter ?? this.fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter ?? this.fsrsDifficultyAfter,
      durationMs: durationMs ?? this.durationMs,
      questionType: questionType ?? this.questionType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
