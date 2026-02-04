/// Session 级统计语义定义
/// 这是 daily_stats 写入前的唯一语义来源
library session_stat_policy;

/// Session 内可记录的原子行为
enum SessionEventType {
  /// 首次学习一个新单词
  firstLearn,

  /// 单词复习（无论对错）
  review,

  /// 复习答错
  reviewFailed,

  /// 标记为已掌握
  markMastered,

  /// 假名复习
  kanaReview,
}

/// 单次 Session 中累积的统计上下文
class SessionStatAccumulator {
  int learnedCount;
  int reviewCount;
  int failedCount;
  int masteredCount;
  int kanaReviewCount;

  SessionStatAccumulator({
    this.learnedCount = 0,
    this.reviewCount = 0,
    this.failedCount = 0,
    this.masteredCount = 0,
    this.kanaReviewCount = 0,
  });

  void applyDelta(SessionStatDelta delta) {
    learnedCount += delta.learned;
    reviewCount += delta.reviewed;
    failedCount += delta.failed;
    masteredCount += delta.mastered;
    kanaReviewCount += delta.kanaReviewed;
  }
}

/// 单个事件对应的统计增量
class SessionStatDelta {
  final int learned;
  final int reviewed;
  final int failed;
  final int mastered;
  final int kanaReviewed;

  const SessionStatDelta({
    this.learned = 0,
    this.reviewed = 0,
    this.failed = 0,
    this.mastered = 0,
    this.kanaReviewed = 0,
  });
}

/// Session 统计语义策略（核心）
class SessionStatPolicy {
  /// 根据事件类型生成统计增量
  static SessionStatDelta deltaFor(SessionEventType type) {
    switch (type) {
      case SessionEventType.firstLearn:
        return const SessionStatDelta(learned: 1);

      case SessionEventType.review:
        return const SessionStatDelta(reviewed: 1);

      case SessionEventType.reviewFailed:
        return const SessionStatDelta(reviewed: 1, failed: 1);

      case SessionEventType.markMastered:
        return const SessionStatDelta(mastered: 1);

      case SessionEventType.kanaReview:
        return const SessionStatDelta(kanaReviewed: 1);
    }
  }
}
