/// 学习状态枚举（单词、语法、假名统一状态）
///
/// 无记录 = 未学习。学习流程：翻到即创建 learning(1) 记录并进入 SRS。
enum LearningStatus {
  /// 未学习 / 未开始
  unlearned(0, '未学习'),

  /// SRS 学习中（翻到即标记）
  learning(1, '学习中'),

  /// 已掌握（用户主动标记，退出 SRS）
  mastered(2, '已掌握'),

  /// 已忽略（用户主动跳过）
  ignored(3, '已忽略');

  const LearningStatus(this.value, this.description);

  final int value;

  final String description;

  static LearningStatus fromValue(
    int value, {
    LearningStatus fallback = LearningStatus.learning,
  }) {
    return LearningStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => fallback,
    );
  }
}
