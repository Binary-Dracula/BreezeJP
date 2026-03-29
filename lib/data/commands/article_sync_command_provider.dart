import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../queries/article_remote_query_provider.dart';
import '../repositories/article_repository_provider.dart';
import 'article_sync_command.dart';

/// ArticleSyncCommand Provider
final articleSyncCommandProvider = Provider<ArticleSyncCommand>((ref) {
  return ArticleSyncCommand(
    remoteQuery: ref.read(articleRemoteQueryProvider),
    articleRepository: ref.read(articleRepositoryProvider),
    detailRepository: ref.read(articleDetailRepositoryProvider),
  );
});
