/// 五十音学习状态模型
/// 支持 SRS 复习
class KanaLearningState {
  final int id;
  final int? kanaId;
  final int isLearned;
  final String? lastReview;
  final String? nextReview;
  final double easiness;
  final int interval;

  KanaLearningState({
    required this.id,
    this.kanaId,
    this.isLearned = 0,
    this.lastReview,
    this.nextReview,
    this.easiness = 2.5,
    this.interval = 0,
  });

  /// 是否已学习
  bool get learned => isLearned == 1;

  factory KanaLearningState.fromMap(Map<String, dynamic> map) {
    return KanaLearningState(
      id: map['id'],
      kanaId: map['kana_id'],
      isLearned: map['is_learned'] ?? 0,
      lastReview: map['last_review'],
      nextReview: map['next_review'],
      easiness: (map['easiness'] ?? 2.5).toDouble(),
      interval: map['interval'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kana_id': kanaId,
      'is_learned': isLearned,
      'last_review': lastReview,
      'next_review': nextReview,
      'easiness': easiness,
      'interval': interval,
    };
  }

  /// 创建副本并更新字段
  KanaLearningState copyWith({
    int? id,
    int? kanaId,
    int? isLearned,
    String? lastReview,
    String? nextReview,
    double? easiness,
    int? interval,
  }) {
    return KanaLearningState(
      id: id ?? this.id,
      kanaId: kanaId ?? this.kanaId,
      isLearned: isLearned ?? this.isLearned,
      lastReview: lastReview ?? this.lastReview,
      nextReview: nextReview ?? this.nextReview,
      easiness: easiness ?? this.easiness,
      interval: interval ?? this.interval,
    );
  }
}
