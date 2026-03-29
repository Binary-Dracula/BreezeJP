import 'dart:convert';
import 'article_item.dart';
import 'article_summary.dart';

/// 文章详情模型（用于详情页，包含分句内容）
/// 继承 ArticleSummary，额外包含 items 字段
class ArticleDetail extends ArticleSummary {
  final List<ArticleItem> items;

  const ArticleDetail({
    required super.id,
    required super.title,
    required super.cleanTitle,
    required super.publishedAt,
    required super.audioUrl,
    required super.durationMs,
    required super.sentenceCount,
    required super.isArchived,
    required this.items,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final summary = ArticleSummary.fromJson(json);
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => ArticleItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ArticleDetail(
      id: summary.id,
      title: summary.title,
      cleanTitle: summary.cleanTitle,
      publishedAt: summary.publishedAt,
      audioUrl: summary.audioUrl,
      durationMs: summary.durationMs,
      sentenceCount: summary.sentenceCount,
      isArchived: summary.isArchived,
      items: items,
    );
  }

  /// 从 SQLite 行 + items JSON 字符串构建
  factory ArticleDetail.fromMapWithItems(
    Map<String, dynamic> map,
    String itemsJson,
  ) {
    final summary = ArticleSummary.fromMap(map);
    final rawItems = jsonDecode(itemsJson) as List<dynamic>;
    final items = rawItems
        .map((e) => ArticleItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ArticleDetail(
      id: summary.id,
      title: summary.title,
      cleanTitle: summary.cleanTitle,
      publishedAt: summary.publishedAt,
      audioUrl: summary.audioUrl,
      durationMs: summary.durationMs,
      sentenceCount: summary.sentenceCount,
      isArchived: summary.isArchived,
      items: items,
    );
  }

  @override
  String toString() =>
      'ArticleDetail{id: $id, title: $title, items: ${items.length}}';
}
