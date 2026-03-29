import 'article_summary.dart';

/// 文章列表 API 响应的分页元信息
class ArticleListMeta {
  final int total;
  final bool hasMore;
  final String? cursor;
  final String serverTime;

  const ArticleListMeta({
    required this.total,
    required this.hasMore,
    this.cursor,
    required this.serverTime,
  });

  factory ArticleListMeta.fromJson(Map<String, dynamic> json) {
    return ArticleListMeta(
      total: json['total'] as int,
      hasMore: json['has_more'] as bool,
      cursor: json['cursor'] as String?,
      serverTime: json['server_time'] as String,
    );
  }
}

/// 文章列表 API 完整响应
class ArticleListResponse {
  final List<ArticleSummary> data;
  final ArticleListMeta meta;

  const ArticleListResponse({required this.data, required this.meta});

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>;
    return ArticleListResponse(
      data: rawData
          .map((e) => ArticleSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: ArticleListMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }
}
