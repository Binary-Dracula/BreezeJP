import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/article/article_item.dart';

/// 文章详情数据仓库
/// 负责 article_details 表的操作（以 JSON 字符串存储 items）
class ArticleDetailRepository {
  ArticleDetailRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  /// 插入或更新文章详情（items 序列化为 JSON 字符串）
  Future<void> upsertDetail(String articleId, List<ArticleItem> items) async {
    try {
      final db = await _db;
      final itemsJson = jsonEncode(items.map((e) => e.toJson()).toList());
      await db.insert('article_details', {
        'article_id': articleId,
        'items': itemsJson,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      logger.dbQuery(
        table: 'article_details',
        where: 'article_id = $articleId',
        resultCount: 1,
      );
    } catch (e, st) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'article_details',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 根据文章 ID 获取 items 列表
  /// 如果不存在则返回 null
  Future<List<ArticleItem>?> getItemsByArticleId(String articleId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'article_details',
        where: 'article_id = ?',
        whereArgs: [articleId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final itemsJson = rows.first['items'] as String;
      final rawList = jsonDecode(itemsJson) as List<dynamic>;
      final items = rawList
          .map((e) => ArticleItem.fromJson(e as Map<String, dynamic>))
          .toList();
      logger.dbQuery(
        table: 'article_details',
        where: 'article_id = $articleId',
        resultCount: items.length,
      );
      return items;
    } catch (e, st) {
      logger.dbError(
        operation: 'SELECT',
        table: 'article_details',
        dbError: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// 检查某篇文章的详情是否已缓存
  Future<bool> hasDetail(String articleId) async {
    final items = await getItemsByArticleId(articleId);
    return items != null && items.isNotEmpty;
  }
}
