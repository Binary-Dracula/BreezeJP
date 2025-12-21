import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/word.dart';

/// 单词数据仓库
/// 负责所有与单词相关的数据库操作
class WordRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 单词查询 ====================

  /// 根据 ID 获取单词
  Future<Word?> getWordById(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'words',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'words',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return Word.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取所有单词
  Future<List<Word>> getAllWords({int? limit, int? offset}) async {
    try {
      final db = await _db;
      final results = await db.query(
        'words',
        orderBy: 'id ASC',
        limit: limit,
        offset: offset,
      );

      logger.dbQuery(table: 'words', where: null, resultCount: results.length);

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

}
