import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/read/example_api_item.dart';

/// 外部例句 API Repository
/// 职责：
/// - 调用外部 API
/// - 将原始响应转换为 ExampleApiItem DTO
/// - 不包含任何业务语义或筛选逻辑
class ExampleApiRepository {
  final _client = DioClient.instance;

  /// 示例：获取单词列表
  Future<List<ExampleApiItem>> fetchWords({
    String? level,
    int? limit,
  }) async {
    try {
      final response = await _client.get(
        ApiEndpoints.words,
        queryParameters: {
          if (level != null) 'level': level,
          if (limit != null) 'limit': limit,
        },
      );

      // 假设返回的是 JSON 数组
      if (response.data is List) {
        final rawList = List<Map<String, dynamic>>.from(response.data);
        return rawList.map(ExampleApiItem.fromMap).toList();
      }

      throw NetworkException('数据格式错误');
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('获取单词列表失败: $e');
    }
  }

  /// 示例：获取单词详情
  Future<ExampleApiItem> fetchWordDetail(int wordId) async {
    try {
      final path = ApiEndpoints.replaceParams(ApiEndpoints.wordDetail, {
        'id': wordId,
      });

      final response = await _client.get(path);

      if (response.data is Map) {
        return ExampleApiItem.fromMap(
          Map<String, dynamic>.from(response.data),
        );
      }

      throw NetworkException('数据格式错误');
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('获取单词详情失败: $e');
    }
  }

  /// 示例：提交学习进度
  Future<void> submitLearningProgress({
    required int wordId,
    required bool isCorrect,
    required int timeSpent,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.learningProgress,
        data: {
          'word_id': wordId,
          'is_correct': isCorrect,
          'time_spent': timeSpent,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('提交学习进度失败: $e');
    }
  }

  /// 示例：下载音频文件
  Future<void> downloadAudio({
    required String filename,
    required String savePath,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final path = ApiEndpoints.replaceParams(ApiEndpoints.audioDownload, {
        'filename': filename,
      });

      await _client.download(path, savePath, onReceiveProgress: onProgress);
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('下载音频失败: $e');
    }
  }
}
