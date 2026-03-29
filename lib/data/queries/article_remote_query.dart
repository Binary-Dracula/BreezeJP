import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../models/article/article_detail.dart';
import '../models/article/article_list_response.dart';

/// 文章远程查询服务
/// 负责从 Cloudflare Workers API 获取文章数据
class ArticleRemoteQuery {
  final _dio = DioClient.instance.dio;

  /// 获取文章列表（支持增量同步）
  ///
  /// [since] ISO8601 时间字符串，只返回该时间之后更新的文章；null 表示全量拉取
  /// [limit] 每页数量，默认 50
  /// [cursor] 分页游标，用于获取下一页
  Future<ArticleListResponse> fetchArticles({
    String? since,
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (since != null) queryParams['since'] = since;
    if (cursor != null) queryParams['cursor'] = cursor;

    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.articles,
      queryParameters: queryParams,
    );

    return ArticleListResponse.fromJson(response.data!);
  }

  /// 获取单篇文章详情（包含 items）
  Future<ArticleDetail> fetchArticleDetail(String id) async {
    final path = ApiEndpoints.replaceParams(ApiEndpoints.articleDetail, {
      'id': id,
    });
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data!['data'] as Map<String, dynamic>;
    return ArticleDetail.fromJson(data);
  }
}
