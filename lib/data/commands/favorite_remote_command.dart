import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

class FavoriteToggleResult {
  const FavoriteToggleResult({required this.favorited});

  final bool favorited;

  factory FavoriteToggleResult.fromJson(Map<String, dynamic> json) {
    return FavoriteToggleResult(favorited: json['favorited'] == true);
  }
}

class FavoriteRemoteCommand {
  final _dio = DioClient.instance.dio;

  Future<FavoriteToggleResult> toggleWordFavorite({
    required String wordId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.wordFavoritesToggle,
      data: {'word_id': wordId},
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return FavoriteToggleResult.fromJson(data);
  }

  Future<FavoriteToggleResult> toggleWordExampleFavorite({
    required String exampleId,
    required String wordId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.exampleFavoritesToggle,
      data: {'example_id': exampleId, 'word_id': wordId},
    );
    final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
    return FavoriteToggleResult.fromJson(data);
  }
}
