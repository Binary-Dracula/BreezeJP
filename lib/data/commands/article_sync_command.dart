import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_logger.dart';
import '../models/article/article_summary.dart';
import '../queries/article_remote_query.dart';
import '../repositories/article_detail_repository.dart';
import '../repositories/article_repository.dart';

/// 文章增量同步命令
/// 从远程 API 拉取文章数据并写入本地 SQLite 缓存
class ArticleSyncCommand {
  ArticleSyncCommand({
    required ArticleRemoteQuery remoteQuery,
    required ArticleRepository articleRepository,
    required ArticleDetailRepository detailRepository,
  }) : _remoteQuery = remoteQuery,
       _articleRepository = articleRepository,
       _detailRepository = detailRepository;

  final ArticleRemoteQuery _remoteQuery;
  final ArticleRepository _articleRepository;
  final ArticleDetailRepository _detailRepository;

  static const _lastSyncKey = 'articles_last_sync_time';

  /// 增量同步文章列表
  ///
  /// 读取上次同步时间，只拉取增量数据，支持多页游标分页。
  /// 返回本次同步的文章数量。
  Future<int> syncArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(_lastSyncKey);

    logger.info('[ArticleSync] 开始同步，lastSync=$lastSync');

    int totalSynced = 0;
    String? cursor;

    do {
      final response = await _remoteQuery.fetchArticles(
        since: lastSync,
        cursor: cursor,
      );

      final articles = response.data;
      if (articles.isNotEmpty) {
        // 分离已归档 vs 正常文章
        final archived = articles.where((a) => a.isArchived).toList();
        final normal = articles.where((a) => !a.isArchived).toList();

        await _articleRepository.upsertArticles(normal);
        for (final a in archived) {
          await _articleRepository.upsertArticle(a);
          await _articleRepository.markArchived(a.id);
        }

        totalSynced += articles.length;
      }

      // 保存服务器时间（每页更新一次，最终取最后一页的时间）
      await prefs.setString(_lastSyncKey, response.meta.serverTime);

      cursor = response.meta.hasMore ? response.meta.cursor : null;
    } while (cursor != null);

    logger.info('[ArticleSync] 同步完成，共 $totalSynced 篇');
    return totalSynced;
  }

  /// 同步单篇文章详情（含 items）
  ///
  /// 同时更新文章摘要缓存（以防列表未同步）。
  Future<void> syncArticleDetail(String id) async {
    logger.info('[ArticleSync] 同步文章详情: $id');
    final detail = await _remoteQuery.fetchArticleDetail(id);

    // 更新摘要缓存
    final summary = ArticleSummary(
      id: detail.id,
      title: detail.title,
      cleanTitle: detail.cleanTitle,
      publishedAt: detail.publishedAt,
      audioUrl: detail.audioUrl,
      durationMs: detail.durationMs,
      sentenceCount: detail.sentenceCount,
      isArchived: detail.isArchived,
    );
    await _articleRepository.upsertArticle(summary);

    // 写入 items 详情
    await _detailRepository.upsertDetail(id, detail.items);
    logger.info('[ArticleSync] 文章详情同步完成: $id，items=${detail.items.length}');
  }
}
