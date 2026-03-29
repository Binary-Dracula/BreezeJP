import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/article_repository_provider.dart';
import 'article_query.dart';

/// ArticleQuery Provider
final articleQueryProvider = Provider<ArticleQuery>((ref) {
  return ArticleQuery(
    articleRepository: ref.read(articleRepositoryProvider),
    detailRepository: ref.read(articleDetailRepositoryProvider),
  );
});
