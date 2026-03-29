import '../models/article/article_detail.dart';
import '../models/article/article_summary.dart';
import '../repositories/article_detail_repository.dart';
import '../repositories/article_repository.dart';

/// 文章查询服务（本地 SQLite 数据源）
class ArticleQuery {
  ArticleQuery({
    required ArticleRepository articleRepository,
    required ArticleDetailRepository detailRepository,
  }) : _articleRepository = articleRepository,
       _detailRepository = detailRepository;

  final ArticleRepository _articleRepository;
  final ArticleDetailRepository _detailRepository;

  /// 获取所有文章摘要列表（按发布时间降序）
  Future<List<ArticleSummary>> getArticles() async {
    return _articleRepository.getAllArticles();
  }

  /// 根据 ID 获取文章详情（含 items）
  ///
  /// 如果本地已缓存 items 则直接返回，否则返回 null（调用方应触发同步）
  Future<ArticleDetail?> getArticleById(String id) async {
    final summary = await _articleRepository.getById(id);
    if (summary == null) return null;

    final items = await _detailRepository.getItemsByArticleId(id);
    if (items == null) return null;

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
}
