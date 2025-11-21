import '../../data/models/study_log.dart';

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
