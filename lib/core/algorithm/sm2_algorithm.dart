import '../../data/models/study_log.dart';
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
      newInterval = 1; // 重置为 1 天 (或者更短，如 1 分钟，但在天维度下设为 1)
      // Ease Factor 不变或轻微减少，这里保持不变是常见做法，或者按 Anki 逻辑减少
      // Anki: if quality == 0, newInterval = 0 (relearn steps)
      // 这里简化处理：失败重置
    } else {
      // 成功
      // SM-2 标准逻辑：
      // - 首次复习后（reviews=0）：interval = 6 天
      // - 第二次复习后（reviews=1）：interval = 6 × EF
      // - 后续复习：interval = previous × EF
      if (input.reviews == 0) {
        newInterval = 6; // 首次复习后跳到 6 天
      } else if (input.reviews == 1) {
        newInterval = (6 * input.easeFactor).roundToDouble();
      } else {
        newInterval = (input.interval * input.easeFactor).roundToDouble();
      }

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

    // 计算下次复习时间
    // 如果是 Again，通常是几分钟后，但为了数据库存储方便，这里设为当前时间 + 1天 (或者由上层逻辑决定是否进入学习队列)
    // 这里我们假设 interval 是天数。
    // 如果 interval < 1，说明是分钟级复习，nextReviewAt 应该是 minutes later。
    // 为了简化 MVP，我们统一按天计算，Again = 0 天 (立即/今日)

    DateTime nextReviewAt;
    if (input.rating == ReviewRating.again) {
      newInterval = 0; // 标记为 0，表示需要立即复习
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
