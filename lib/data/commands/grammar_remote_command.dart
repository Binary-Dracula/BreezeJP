import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

class GrammarStateUpsert {
  const GrammarStateUpsert({
    required this.grammarId,
    required this.learningStatus,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.streak,
    this.totalReviews,
    this.failCount,
    this.interval,
    this.easeFactor,
    this.stability,
    this.difficulty,
  });

  final int grammarId;
  final int learningStatus;
  final int? nextReviewAt;
  final int? lastReviewedAt;
  final int? streak;
  final int? totalReviews;
  final int? failCount;
  final double? interval;
  final double? easeFactor;
  final double? stability;
  final double? difficulty;

  Map<String, dynamic> toJson() {
    return {
      'grammar_id': grammarId,
      'learning_status': learningStatus,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (streak != null) 'streak': streak,
      if (totalReviews != null) 'total_reviews': totalReviews,
      if (failCount != null) 'fail_count': failCount,
      if (interval != null) 'interval': interval,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
    };
  }
}

class GrammarRemoteCommand {
  final _dio = DioClient.instance.dio;

  Future<void> saveStates(List<GrammarStateUpsert> states) async {
    if (states.isEmpty) {
      return;
    }

    await _dio.post<void>(
      ApiEndpoints.grammarStates,
      data: {'states': states.map((state) => state.toJson()).toList()},
    );
  }
}
