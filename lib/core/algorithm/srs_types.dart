/// 复习评分（从 study_log.dart 迁移至此，作为算法系统的核心类型）
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
        return '#F44336';
      case ReviewRating.hard:
        return '#FF9800';
      case ReviewRating.good:
        return '#4CAF50';
      case ReviewRating.easy:
        return '#2196F3';
    }
  }

  /// 是否答对（用于 SRS 计算）
  bool get isCorrect => this != ReviewRating.again;
}

/// SRS 算法的输入状态
class SRSInput {
  /// 当前间隔（天）
  final double interval;

  /// 当前 Ease Factor (SM-2)
  final double easeFactor;

  /// 当前 Stability (FSRS)
  final double stability;

  /// 当前 Difficulty (FSRS)
  final double difficulty;

  /// 累计复习次数
  final int reviews;

  /// 累计失败次数
  final int lapses;

  /// 本次评分
  final ReviewRating rating;

  /// 距离上次复习的时间（天）
  /// 如果是第一次学习，则为 0
  final double elapsedDays;

  SRSInput({
    required this.interval,
    required this.easeFactor,
    required this.stability,
    required this.difficulty,
    required this.reviews,
    required this.lapses,
    required this.rating,
    required this.elapsedDays,
  });

  /// 创建初始状态（第一次学习）
  factory SRSInput.initial(ReviewRating rating) {
    return SRSInput(
      interval: 0,
      easeFactor: 2.5,
      stability: 0,
      difficulty: 0,
      reviews: 0,
      lapses: 0,
      rating: rating,
      elapsedDays: 0,
    );
  }
}

/// SRS 算法的输出结果
class SRSOutput {
  /// 下次复习时间
  final DateTime nextReviewAt;

  /// 新的间隔（天）
  final double interval;

  /// 新的 Ease Factor (SM-2)
  final double easeFactor;

  /// 新的 Stability (FSRS)
  final double stability;

  /// 新的 Difficulty (FSRS)
  final double difficulty;

  SRSOutput({
    required this.nextReviewAt,
    required this.interval,
    required this.easeFactor,
    required this.stability,
    required this.difficulty,
  });
}

/// 算法类型
enum AlgorithmType { sm2, fsrs }

/// SRS 算法接口
abstract class SRSAlgorithm {
  /// 计算下一次复习状态
  SRSOutput calculate(SRSInput input);

  /// 获取算法类型
  AlgorithmType get type;
}
