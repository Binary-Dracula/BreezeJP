import 'srs_types.dart';

/// SM-2 算法实现
/// 基于 SuperMemo-2 算法的变体，广泛用于 Anki 等软件
class SM2Algorithm implements SRSAlgorithm {
  @override
  AlgorithmType get type => AlgorithmType.sm2;

  @override
  SRSOutput calculate(SRSInput input) {
    double newInterval;
    double newEaseFactor = input.easeFactor;

    // 评分转换：
    // Breeze: Again(1), Hard(2), Good(3), Easy(4)
    // SM-2: 0-5 scale usually.
    // Mapping:
    // Again -> 0 (Complete blackout)
    // Hard -> 3 (Recall with difficulty)
    // Good -> 4 (Recall with hesitation)
    // Easy -> 5 (Perfect recall)

    int quality;
    switch (input.rating) {
      case ReviewRating.again:
        quality = 0;
        break;
      case ReviewRating.hard:
        quality = 3;
        break;
      case ReviewRating.good:
        quality = 4;
        break;
      case ReviewRating.easy:
        quality = 5;
        break;
    }

    if (quality < 3) {
      // 失败 (Again)
      newInterval = 0; // 标记为 0，表示需要重新排入当次复习或者很快（例如1分钟后）

      // 答错惩罚 EF
      newEaseFactor = input.easeFactor - 0.20;
      if (newEaseFactor < 1.3) newEaseFactor = 1.3;
    } else {
      // 成功
      // SM-2 标准逻辑：
      // - 首次或当前 interval≤1（初次学习）：interval = 6 天
      // - 后续复习：interval = previous × EF
      // 修正：如果 previous interval 是 0 (来自 Again)，则强制设为 1，防止计算结果永远为 0
      final effectiveInterval = input.interval <= 0 ? 1.0 : input.interval;

      if (input.reviews == 0) {
        newInterval = 6; // 首次复习（直接毕业）：6 天
      } else {
        newInterval = (effectiveInterval * input.easeFactor).roundToDouble();
      }

      // 额外保护：成功的复习至少间隔 1 天，确保不会在当天重复出现
      if (newInterval < 1) newInterval = 1;

      // 更新 Ease Factor
      // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
      newEaseFactor =
          input.easeFactor +
          (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (newEaseFactor < 1.3) newEaseFactor = 1.3;
    }

    // 针对 Hard 的特殊处理 (Anki 逻辑：Hard 间隔为当前间隔 * 1.2)
    if (input.rating == ReviewRating.hard && input.reviews > 1) {
      newInterval = (input.interval * 1.2).roundToDouble();
      // Hard 也会轻微减少 EF
      newEaseFactor = input.easeFactor - 0.15;
      if (newEaseFactor < 1.3) newEaseFactor = 1.3;
    }

    // 针对 Easy 的特殊处理 (Anki 逻辑：Easy 额外奖励)
    if (input.rating == ReviewRating.easy) {
      newEaseFactor += 0.15;
      if (input.reviews > 1) {
        newInterval = (input.interval * input.easeFactor * 1.3).roundToDouble();
      }
    }

    DateTime nextReviewAt;
    if (input.rating == ReviewRating.again) {
      newInterval = 0; // 标记为 0，表示需要立即/重新复习
      nextReviewAt = DateTime.now().add(const Duration(minutes: 1));
    } else {
      nextReviewAt = DateTime.now().add(Duration(days: newInterval.ceil()));
    }

    return SRSOutput(
      nextReviewAt: nextReviewAt,
      interval: newInterval,
      easeFactor: newEaseFactor,
      stability: 0, // SM-2 不使用
      difficulty: 0, // SM-2 不使用
    );
  }
}
