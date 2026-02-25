import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'article_query.dart';

/// ArticleQuery 的提供者
final articleQueryProvider = Provider<ArticleQuery>((ref) {
  return ArticleQuery();
});
