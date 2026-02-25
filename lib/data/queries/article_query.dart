import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/article/article.dart';

/// 文章查询服务
class ArticleQuery {
  final String _mockAssetPath = 'assets/mock/test_output.json';

  /// 获取所有文章列表
  Future<List<Article>> getArticles() async {
    final jsonString = await rootBundle.loadString(_mockAssetPath);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => Article.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 根据 ID 获取单篇文章
  Future<Article?> getArticleById(String id) async {
    final articles = await getArticles();
    try {
      return articles.firstWhere((article) => article.id == id);
    } catch (_) {
      return null;
    }
  }
}
