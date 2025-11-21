import 'dart:math';
import '../../data/models/study_log.dart';
import 'srs_types.dart';

/// FSRS v4 算法实现
/// Free Spaced Repetition Scheduler
/// 论文/源码参考: https://github.com/open-spaced-repetition/fsrs4anki
class FSRSAlgorithm implements SRSAlgorithm {
  @override
  AlgorithmType get type => AlgorithmType.fsrs;

  // 默认参数 (Weights) - FSRS v4.5 Default
  static const List<double> w = [
    0.4,
    0.6,
    2.4,
    5.8,
    4.93,
    0.94,
    0.86,
    0.01,
    1.49,
    0.14,
    0.94,
    2.18,
    0.05,
    0.34,
    1.26,
    0.29,
    2.61,
  ];

  @override
  SRSOutput calculate(SRSInput input) {
    if (input.reviews == 0) {
      // 初次学习
      return _computeInitialState(input);
    } else {
      // 复习
      return _computeNextState(input);
    }
  }

  /// 计算初始状态 (First Learn)
  SRSOutput _computeInitialState(SRSInput input) {
    // S0(G) = w[G-1]
    // G: Rating (1=Again, 2=Hard, 3=Good, 4=Easy)
    // w[0]..w[3] 对应 Again..Easy 的初始 Stability

    int ratingIndex = input.rating.value - 1; // 0..3
    double s = w[ratingIndex];

    // D0(G) = w[4] - (G-3) * w[5]
    // G: Rating (1..4)
    // D0 = w[4] - (rating - 3) * w[5]
    double d = w[4] - (input.rating.value - 3) * w[5];

    // 限制 D 范围 [1, 10]
    d = d.clamp(1.0, 10.0);

    return SRSOutput(
      nextReviewAt: _calculateNextReview(s),
      interval: _calculateInterval(s),
      easeFactor: 0, // FSRS 不使用
      stability: s,
      difficulty: d,
    );
  }

  /// 计算后续状态 (Review)
  SRSOutput _computeNextState(SRSInput input) {
    double s = input.stability;
    double d = input.difficulty;
    double r = input.rating.value.toDouble(); // 1..4
    double interval = input.elapsedDays; // 实际经过的天数 (IVL)

    // 1. 更新 Difficulty (D)
    // D' = D - w[6] * (R - 3)
    // D' = D' * (1 - w[7]) + MeanReversion * w[7] (这里简化，暂不引入 MeanReversion，或者使用 w[4] 作为 Mean)
    // MeanReversion target is w[4] usually.

    double nextD = d - w[6] * (r - 3);
    // Apply Mean Reversion: nextD = w[7] * w[4] + (1 - w[7]) * nextD
    nextD = w[7] * w[4] + (1 - w[7]) * nextD;
    nextD = nextD.clamp(1.0, 10.0);

    // 2. 更新 Stability (S)
    double nextS;

    if (input.rating == ReviewRating.again) {
      // 忘记 (Again)
      // S'(S, D, R) = w[8] * exp(w[9] * (D - 1)) * S ^ w[10] * exp(w[11] * (1 - R))
      // 这里 R 是 Retrievability? 不，公式里的 R 通常指 Rating 或 Retrievability。
      // FSRS v4 公式:
      // S_recall = S * (1 + exp(w[8]) * (11 - D) * S^(-w[9]) * (exp((1 - R) * w[10]) - 1))
      // S_forget = w[11] * D^(-w[12]) * ((S + 1)^w[13] - 1) * exp((1 - R) * w[14])

      // 让我们使用更标准的 v4.5 公式实现
      // Retrievability R = (1 + FACTOR * t / S) ^ -1
      // FACTOR = 19/81 approx 0.2345 (for 90% retention request)

      // 简化起见，直接套用 v4.5 的核心更新逻辑

      // Forgetting (Again):
      // nextS = w[11] * D^(-w[12]) * ((S + 1)^w[13] - 1) * exp((1 - R_retrievability) * w[14])
      // 这里 R_retrievability 需要计算
      // R = (1 + 19/81 * interval / S)^-1

      // 但如果是 Again，通常 interval 很短，或者 interval 是上次的 interval。
      // 这里的 interval 是 elapsedDays。

      nextS =
          w[11] *
          pow(d, -w[12]) *
          (pow(s + 1, w[13]) - 1) *
          exp((1 - _retrievability(interval, s)) * w[14]);
    } else {
      // 记得 (Hard, Good, Easy)
      // S' = S * (1 + exp(w[8]) * (11 - D) * S^(-w[9]) * (exp((1 - R_retrievability) * w[10]) - 1))

      double retrievability = _retrievability(interval, s);

      nextS =
          s *
          (1 +
              exp(w[8]) *
                  (11 - d) *
                  pow(s, -w[9]) *
                  (exp((1 - retrievability) * w[10]) - 1));
    }

    // 限制 S
    nextS = max(0.1, nextS); // 最小 0.1 天

    return SRSOutput(
      nextReviewAt: _calculateNextReview(nextS),
      interval: _calculateInterval(nextS),
      easeFactor: 0,
      stability: nextS,
      difficulty: nextD,
    );
  }

  /// 计算可提取性 (Retrievability)
  /// R(t, S) = (1 + C * t / S) ^ -1
  /// C = 19/81 (for request retention 0.9)
  double _retrievability(double t, double s) {
    if (s == 0) return 0;
    return pow(1 + (19 / 81) * t / s, -1).toDouble();
  }

  /// 根据 Stability 计算下一次间隔
  /// I(S) = S * (1/R_request - 1) / (19/81)
  /// R_request = 0.9
  /// Simplified: I = S * 9 * (1/0.9 - 1) = S * 9 * 0.111... = S
  /// Wait, standard formula: I = S * 9 * (1/r - 1)
  /// If r=0.9, term is (1.11 - 1) = 0.11. 9 * 0.11 = 1. So I = S.
  /// 也就是说，当目标保留率为 90% 时，间隔等于稳定性。
  double _calculateInterval(double s) {
    // 假设目标保留率 0.9
    // I = S
    // 可以添加一个最大间隔限制 (如 36500 天)
    return s.clamp(0.0, 36500.0);
  }

  DateTime _calculateNextReview(double s) {
    double days = _calculateInterval(s);
    // 转换为分钟或天
    // 如果 days < 1，可能是分钟级
    if (days < 1.0) {
      // 比如 0.1 天 = 2.4 小时
      // 最小 1 分钟
      int minutes = (days * 24 * 60).round();
      if (minutes < 1) minutes = 1;
      return DateTime.now().add(Duration(minutes: minutes));
    } else {
      return DateTime.now().add(Duration(days: days.round()));
    }
  }
}
