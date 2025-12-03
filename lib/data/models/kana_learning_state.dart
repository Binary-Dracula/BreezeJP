/// 五十音学习状态枚举
/// 与 study_words.user_state 保持一致
enum KanaLearningStatus {
  notLearned, // 0 - 未学
  learning, // 1 - 学习中
  mastered, // 2 - 已掌握
  ignored, // 3 - 忽略
}

/// 五十音学习状态模型
/// 与 study_words 表结构保持一致，支持 SM-2 和 FSRS 双算法
class KanaLearningState {
  final int id;
  final int userId;
  final int kanaId;

  /// 学习状态：0=未学, 1=学习中, 2=已掌握, 3=忽略
  final KanaLearningStatus learningStatus;

  /// 下次复习时间 (Unix 时间戳)
  final int? nextReviewAt;

  /// 上次复习时间 (Unix 时间戳)
  final int? lastReviewedAt;

  /// 连续答对次数
  final int streak;

  /// 累计复习次数
  final int totalReviews;

  /// 累计失败次数
  final int failCount;

  /// [SM-2] 复习间隔 (天)
  final double interval;

  /// [SM-2] 难度系数
  final double easeFactor;

  /// [FSRS] 记忆稳定性 (S)
  final double stability;

  /// [FSRS] 记忆难度 (D)
  final double difficulty;

  /// 创建时间 (Unix 时间戳)
  final int createdAt;

  /// 更新时间 (Unix 时间戳)
  final int updatedAt;

  KanaLearningState({
    required this.id,
    required this.userId,
    required this.kanaId,
    this.learningStatus = KanaLearningStatus.notLearned,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.streak = 0,
    this.totalReviews = 0,
    this.failCount = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.stability = 0,
    this.difficulty = 0,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// 是否处于掌握状态
  bool get isMastered => learningStatus == KanaLearningStatus.mastered;

  /// 是否处于学习中
  bool get isLearning =>
      learningStatus == KanaLearningStatus.learning ||
      learningStatus == KanaLearningStatus.mastered;

  /// 是否需要复习
  bool get isDueForReview {
    if (nextReviewAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nextReviewAt! <= now;
  }

  factory KanaLearningState.fromMap(Map<String, dynamic> map) {
    final statusValue = (map['learning_status'] as int? ?? 0)
        .clamp(0, KanaLearningStatus.values.length - 1)
        .toInt();
    return KanaLearningState(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      kanaId: map['kana_id'] as int,
      learningStatus: KanaLearningStatus.values[statusValue],
      nextReviewAt: map['next_review_at'] as int?,
      lastReviewedAt: map['last_reviewed_at'] as int?,
      streak: map['streak'] as int? ?? 0,
      totalReviews: map['total_reviews'] as int? ?? 0,
      failCount: map['fail_count'] as int? ?? 0,
      interval: (map['interval'] as num?)?.toDouble() ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      stability: (map['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kana_id': kanaId,
      'learning_status': learningStatus.index,
      'next_review_at': nextReviewAt,
      'last_reviewed_at': lastReviewedAt,
      'streak': streak,
      'total_reviews': totalReviews,
      'fail_count': failCount,
      'interval': interval,
      'ease_factor': easeFactor,
      'stability': stability,
      'difficulty': difficulty,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 用于插入的 Map（不包含 id）
  Map<String, dynamic> toInsertMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// 创建副本并更新字段
  KanaLearningState copyWith({
    int? id,
    int? userId,
    int? kanaId,
    KanaLearningStatus? learningStatus,
    int? nextReviewAt,
    int? lastReviewedAt,
    int? streak,
    int? totalReviews,
    int? failCount,
    double? interval,
    double? easeFactor,
    double? stability,
    double? difficulty,
    int? createdAt,
    int? updatedAt,
  }) {
    return KanaLearningState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kanaId: kanaId ?? this.kanaId,
      learningStatus: learningStatus ?? this.learningStatus,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      streak: streak ?? this.streak,
      totalReviews: totalReviews ?? this.totalReviews,
      failCount: failCount ?? this.failCount,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
