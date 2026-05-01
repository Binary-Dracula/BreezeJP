import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/word_detail.dart';

final wordDetailRemoteQueryProvider = Provider<WordDetailRemoteQuery>((ref) {
  return WordDetailRemoteQuery();
});

class WordDetailRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<WordDetail?> fetchWordDetail(String wordId) async {
    final path = ApiEndpoints.replaceParams(ApiEndpoints.wordDetail, {
      'id': wordId,
    });
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data?['data'];
    if (data is! Map) {
      return null;
    }
    return WordDetail.fromJson(Map<String, dynamic>.from(data));
  }
}
