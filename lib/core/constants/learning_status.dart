/// 学习状态枚举（用于单词与假名的统一生命周期状态）
enum LearningStatus {
  /// 已曝光（看过，但未进入 SRS）
  seen(0, '已曝光'),

  /// SRS 学习中
  learning(1, '学习中'),

  /// 已掌握（退出 SRS）
  mastered(2, '已掌握'),

  /// 已忽略
  ignored(3, '已忽略');

  const LearningStatus(this.value, this.description);

  final int value;

  final String description;

  static LearningStatus fromValue(
    int value, {
    LearningStatus fallback = LearningStatus.seen,
  }) {
    return LearningStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => fallback,
    );
  }
}
