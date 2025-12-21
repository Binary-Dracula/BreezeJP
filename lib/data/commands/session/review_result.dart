class ReviewResult {
  final double intervalAfter;
  final double easeFactorAfter;
  final DateTime nextReviewAtAfter;
  final double? fsrsStabilityAfter;
  final double? fsrsDifficultyAfter;

  const ReviewResult({
    required this.intervalAfter,
    required this.easeFactorAfter,
    required this.nextReviewAtAfter,
    this.fsrsStabilityAfter,
    this.fsrsDifficultyAfter,
  });
}
