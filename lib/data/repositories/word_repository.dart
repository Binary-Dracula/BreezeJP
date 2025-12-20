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

  /// 根据 JLPT 等级获取单词列表
  Future<List<Word>> getWordsByLevel(String jlptLevel) async {
    try {
      final db = await _db;
      final results = await db.query(
        'words',
        where: 'jlpt_level = ?',
        whereArgs: [jlptLevel],
        orderBy: 'id ASC',
      );

      logger.dbQuery(
        table: 'words',
        where: 'jlpt_level = $jlptLevel',
        resultCount: results.length,
      );

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

  /// 搜索单词（按单词文本、假名或罗马音）
  Future<List<Word>> searchWords(String keyword) async {
    try {
      final db = await _db;
      final results = await db.query(
        'words',
        where: 'word LIKE ? OR furigana LIKE ? OR romaji LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
        orderBy: 'id ASC',
      );

      logger.dbQuery(
        table: 'words',
        where: 'keyword = $keyword',
        resultCount: results.length,
      );

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

  /// 获取单词总数
  Future<int> getWordCount({String? jlptLevel}) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM words${jlptLevel != null ? ' WHERE jlpt_level = ?' : ''}',
        jlptLevel != null ? [jlptLevel] : null,
      );

      logger.dbQuery(
        table: 'words',
        where: jlptLevel != null
            ? 'jlpt_level = $jlptLevel (count)'
            : '(count)',
        resultCount: 1,
      );

      return result.first['count'] as int;
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

  // ==================== 随机查询 ====================

  /// 随机获取单词
  Future<List<Word>> getRandomWords({int count = 10, String? jlptLevel}) async {
    try {
      final db = await _db;
      final results = await db.query(
        'words',
        where: jlptLevel != null ? 'jlpt_level = ?' : null,
        whereArgs: jlptLevel != null ? [jlptLevel] : null,
        orderBy: 'RANDOM()',
        limit: count,
      );

      logger.dbQuery(
        table: 'words',
        where: 'RANDOM() limit $count',
        resultCount: results.length,
      );

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
