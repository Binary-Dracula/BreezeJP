import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'article_remote_query.dart';

/// ArticleRemoteQuery Provider
final articleRemoteQueryProvider = Provider<ArticleRemoteQuery>((ref) {
  return ArticleRemoteQuery();
});
