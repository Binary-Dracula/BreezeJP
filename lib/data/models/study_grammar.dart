class StudyGrammar {
  final int id;
  final int userId;
  final int grammarId;
  final int learningStatus; // 0=new, 1=learning, 2=mastered, 3=ignored
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final int streak;
  final int totalReviews;
  final int failCount;
  final double interval;
  final double easeFactor;
  final double stability;
  final double difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyGrammar({
    required this.id,
    required this.userId,
    required this.grammarId,
    this.learningStatus = 0,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.streak = 0,
    this.totalReviews = 0,
    this.failCount = 0,
    this.interval = 0.0,
    this.easeFactor = 2.5,
    this.stability = 0.0,
    this.difficulty = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyGrammar.fromMap(Map<String, dynamic> map) {
    return StudyGrammar(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      grammarId: map['grammar_id'] as int,
      learningStatus: map['learning_status'] as int? ?? 0,
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
      streak: map['streak'] as int? ?? 0,
      totalReviews: map['total_reviews'] as int? ?? 0,
      failCount: map['fail_count'] as int? ?? 0,
      interval: (map['interval'] as num?)?.toDouble() ?? 0.0,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'grammar_id': grammarId,
      'learning_status': learningStatus,
      'next_review_at': nextReviewAt != null
          ? (nextReviewAt!.millisecondsSinceEpoch / 1000).round()
          : null,
      'last_reviewed_at': lastReviewedAt != null
          ? (lastReviewedAt!.millisecondsSinceEpoch / 1000).round()
          : null,
      'streak': streak,
      'total_reviews': totalReviews,
      'fail_count': failCount,
      'interval': interval,
      'ease_factor': easeFactor,
      'stability': stability,
      'difficulty': difficulty,
      'created_at': (createdAt.millisecondsSinceEpoch / 1000).round(),
      'updated_at': (updatedAt.millisecondsSinceEpoch / 1000).round(),
    };
  }

  StudyGrammar copyWith({
    int? id,
    int? userId,
    int? grammarId,
    int? learningStatus,
    DateTime? nextReviewAt,
    DateTime? lastReviewedAt,
    int? streak,
    int? totalReviews,
    int? failCount,
    double? interval,
    double? easeFactor,
    double? stability,
    double? difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyGrammar(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      grammarId: grammarId ?? this.grammarId,
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
