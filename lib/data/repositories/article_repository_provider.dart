import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'article_repository.dart';
import 'article_detail_repository.dart';

/// ArticleRepository Provider
final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return ArticleRepository(() => AppDatabase.instance.database);
});

/// ArticleDetailRepository Provider
final articleDetailRepositoryProvider = Provider<ArticleDetailRepository>((
  ref,
) {
  return ArticleDetailRepository(() => AppDatabase.instance.database);
});
