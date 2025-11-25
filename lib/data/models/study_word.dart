/// 用户学习进度模型
/// 记录用户对每个单词的学习状态和 SRS 数据
class StudyWord {
  final int id;
  final int userId;
  final int wordId;
  final UserWordState userState;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final double interval;
  final double easeFactor;
  final double stability;
  final double difficulty;
  final int streak;
  final int totalReviews;
  final int failCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyWord({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.userState,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.stability = 0,
    this.difficulty = 0,
    this.streak = 0,
    this.totalReviews = 0,
    this.failCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建实例
  factory StudyWord.fromMap(Map<String, dynamic> map) {
    return StudyWord(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      wordId: map['word_id'] as int,
      userState: UserWordState.fromValue(map['user_state'] as int),
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['next_review_at'] as int) * 1000,
            )
          : null,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['last_reviewed_at'] as int) * 1000,
            )
          : null,
      interval: (map['interval'] as num?)?.toDouble() ?? 0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      stability: (map['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0,
      streak: map['streak'] as int? ?? 0,
      totalReviews: map['total_reviews'] as int? ?? 0,
      failCount: map['fail_count'] as int? ?? 0,
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
      'word_id': wordId,
      'user_state': userState.value,
      'next_review_at': nextReviewAt != null
          ? nextReviewAt!.millisecondsSinceEpoch ~/ 1000
          : null,
      'last_reviewed_at': lastReviewedAt != null
          ? lastReviewedAt!.millisecondsSinceEpoch ~/ 1000
          : null,
      'interval': interval,
      'ease_factor': easeFactor,
      'stability': stability,
      'difficulty': difficulty,
      'streak': streak,
      'total_reviews': totalReviews,
      'fail_count': failCount,
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
  StudyWord copyWith({
    int? id,
    int? userId,
    int? wordId,
    UserWordState? userState,
    DateTime? nextReviewAt,
    DateTime? lastReviewedAt,
    double? interval,
    double? easeFactor,
    double? stability,
    double? difficulty,
    int? streak,
    int? totalReviews,
    int? failCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyWord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wordId: wordId ?? this.wordId,
      userState: userState ?? this.userState,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      streak: streak ?? this.streak,
      totalReviews: totalReviews ?? this.totalReviews,
      failCount: failCount ?? this.failCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否需要复习
  bool get needsReview {
    if (userState != UserWordState.learning) return false;
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  /// 是否为新单词
  bool get isNew => userState == UserWordState.newWord && totalReviews == 0;

  /// 学习进度百分比（基于连续答对次数）
  double get progressPercentage {
    // 假设连续答对 5 次即为掌握
    const masteryStreak = 5;
    return (streak / masteryStreak).clamp(0.0, 1.0);
  }
}

/// 用户对单词的状态
enum UserWordState {
  /// 未学习（新单词）
  newWord(0),

  /// 学习中（SRS 正常进行）
  learning(1),

  /// 已掌握（用户主动标记"我已经会了，不需要学习"）
  mastered(2),

  /// 忽略（例如脏词、用户不想学）
  ignored(3);

  const UserWordState(this.value);

  final int value;

  /// 从数据库值创建枚举
  static UserWordState fromValue(int value) {
    return UserWordState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => UserWordState.newWord,
    );
  }

  /// 获取状态描述
  String get description {
    switch (this) {
      case UserWordState.newWord:
        return '未学习';
      case UserWordState.learning:
        return '学习中';
      case UserWordState.mastered:
        return '已掌握';
      case UserWordState.ignored:
        return '已忽略';
    }
  }
}
