import '../../core/constants/learning_status.dart';

/// 用户学习进度模型
/// 记录用户对每个单词的学习状态和 SRS 数据
class StudyWord {
  final int id;
  final int userId;
  final int wordId;
  final LearningStatus userState;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final int? interval;
  final double? easeFactor;
  final double? stability;
  final double? difficulty;
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
    this.interval,
    this.easeFactor,
    this.stability,
    this.difficulty,
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
      userState: LearningStatus.fromValue(map['user_state'] as int),
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
      interval: map['interval'] as int?,
      easeFactor: (map['ease_factor'] as num?)?.toDouble(),
      stability: (map['stability'] as num?)?.toDouble(),
      difficulty: (map['difficulty'] as num?)?.toDouble(),
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
    LearningStatus? userState,
    Object? nextReviewAt = _sentinel,
    Object? lastReviewedAt = _sentinel,
    int? interval,
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
      nextReviewAt: nextReviewAt == _sentinel
          ? this.nextReviewAt
          : nextReviewAt as DateTime?,
      lastReviewedAt: lastReviewedAt == _sentinel
          ? this.lastReviewedAt
          : lastReviewedAt as DateTime?,
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

  static const Object _sentinel = Object();

  /// 是否需要复习
  bool get needsReview {
    if (userState != LearningStatus.learning) return false;
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  /// 是否为新单词
  bool get isNew => userState == LearningStatus.seen && totalReviews == 0;

  /// 学习进度百分比（基于连续答对次数）
  double get progressPercentage {
    // 假设连续答对 5 次即为掌握
    const masteryStreak = 5;
    return (streak / masteryStreak).clamp(0.0, 1.0);
  }
}
