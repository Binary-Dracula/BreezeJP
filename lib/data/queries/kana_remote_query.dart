import '../../core/constants/learning_status.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/kana_learning_state.dart';

class RemoteKanaState {
  const RemoteKanaState({
    required this.kanaId,
    required this.learningStatus,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.streak = 0,
    this.totalReviews = 0,
    this.failCount = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.stability = 0,
    this.difficulty = 0,
  });

  final int kanaId;
  final int learningStatus;
  final int? nextReviewAt;
  final int? lastReviewedAt;
  final int streak;
  final int totalReviews;
  final int failCount;
  final double interval;
  final double easeFactor;
  final double stability;
  final double difficulty;

  KanaLearningState toLearningState({required int userId}) {
    return KanaLearningState(
      id: 0,
      userId: userId,
      kanaId: kanaId,
      learningStatus: LearningStatus.fromValue(learningStatus),
      nextReviewAt: nextReviewAt,
      lastReviewedAt: lastReviewedAt,
      streak: streak,
      totalReviews: totalReviews,
      failCount: failCount,
      interval: interval,
      easeFactor: easeFactor,
      stability: stability,
      difficulty: difficulty,
    );
  }

  factory RemoteKanaState.fromJson(Map<String, dynamic> json) {
    return RemoteKanaState(
      kanaId: _readInt(json['kana_id']),
      learningStatus: _readInt(json['learning_status']),
      nextReviewAt: _readNullableInt(json['next_review_at']),
      lastReviewedAt: _readNullableInt(json['last_reviewed_at']),
      streak: _readInt(json['streak']),
      totalReviews: _readInt(json['total_reviews']),
      failCount: _readInt(json['fail_count']),
      interval: _readDouble(json['interval']),
      easeFactor: _readDouble(json['ease_factor'], fallback: 2.5),
      stability: _readDouble(json['stability']),
      difficulty: _readDouble(json['difficulty']),
    );
  }

  static int _readInt(dynamic value) {
    return switch (value) {
      int number => number,
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    return _readInt(value);
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    return switch (value) {
      int number => number.toDouble(),
      double number => number,
      String text => double.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }
}

class KanaRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<List<RemoteKanaState>> fetchKanaStates() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.meKanaStates,
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data
        .map(
          (item) =>
              RemoteKanaState.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
