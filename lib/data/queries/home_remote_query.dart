import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

class RemoteHomeSummary {
  const RemoteHomeSummary({
    required this.userName,
    required this.reviewCount,
    required this.kanaReviewCount,
    required this.masteredWordCount,
    required this.kanaMasteredCount,
  });

  final String userName;
  final int reviewCount;
  final int kanaReviewCount;
  final int masteredWordCount;
  final int kanaMasteredCount;

  factory RemoteHomeSummary.fromJson(Map<String, dynamic> json) {
    return RemoteHomeSummary(
      userName: (json['user_name'] as String?) ?? '',
      reviewCount: (json['review_count'] as int?) ?? 0,
      kanaReviewCount: (json['kana_review_count'] as int?) ?? 0,
      masteredWordCount: (json['mastered_word_count'] as int?) ?? 0,
      kanaMasteredCount: (json['kana_mastered_count'] as int?) ?? 0,
    );
  }
}

class HomeRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<RemoteHomeSummary> fetchHomeSummary() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.homeSummary,
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return RemoteHomeSummary.fromJson(data);
  }
}
