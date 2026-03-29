import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/article/article_summary.dart';

/// 文章摘要数据仓库
/// 负责 articles 表的 CRUD 操作
class ArticleRepository {
  ArticleRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  /// 插入或更新一条文章摘要记录
  Future<void> upsertArticle(ArticleSummary article) async {
    try {
      final db = await _db;
      await db.insert(
        'articles',
        article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'articles',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 批量插入或更新文章摘要记录
  Future<void> upsertArticles(List<ArticleSummary> articles) async {
    if (articles.isEmpty) return;
    try {
      final db = await _db;
      final batch = db.batch();
      for (final article in articles) {
        batch.insert(
          'articles',
          article.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      logger.dbQuery(
        table: 'articles',
        where: 'batch upsert ${articles.length} rows',
        resultCount: articles.length,
      );
    } catch (e, st) {
      logger.dbError(
        operation: 'BATCH UPSERT',
        table: 'articles',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 查询所有文章摘要，按发布时间降序
  Future<List<ArticleSummary>> getAllArticles({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'articles',
        where: 'is_archived = 0',
        orderBy: 'published_at DESC',
        limit: limit,
        offset: offset,
      );
      logger.dbQuery(
        table: 'articles',
        where: 'is_archived = 0',
        resultCount: rows.length,
      );
      return rows.map(ArticleSummary.fromMap).toList();
    } catch (e, st) {
      logger.dbError(
        operation: 'SELECT',
        table: 'articles',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 根据 ID 查询单篇文章摘要
  Future<ArticleSummary?> getById(String id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'articles',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ArticleSummary.fromMap(rows.first);
    } catch (e, st) {
      logger.dbError(
        operation: 'SELECT',
        table: 'articles',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 将文章标记为已归档
  Future<void> markArchived(String id) async {
    try {
      final db = await _db;
      await db.update(
        'articles',
        {'is_archived': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, st) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'articles',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
