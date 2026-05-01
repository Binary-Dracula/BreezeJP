import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';

class ReferenceRemoteQuery {
  final _dio = DioClient.instance.dio;

  Future<Map<String, dynamic>> fetchReferenceContent() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.reference,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data;
  }
}
