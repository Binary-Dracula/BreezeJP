import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/word_meaning.dart';

/// 单词释义仓库
/// 负责 word_meanings 表的查询
class WordMeaningRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取单词的所有释义
  Future<List<WordMeaning>> getWordMeanings(int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'word_meanings',
        where: 'word_id = ?',
        whereArgs: [wordId],
        orderBy: 'definition_order ASC',
      );

      logger.dbQuery(
        table: 'word_meanings',
        where: 'word_id = $wordId',
        resultCount: results.length,
      );

      return results.map((map) => WordMeaning.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'word_meanings',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 批量获取多个单词的释义
  Future<List<WordMeaning>> getWordMeaningsByWordIds(
    List<int> wordIds,
  ) async {
    if (wordIds.isEmpty) return [];

    try {
      final db = await _db;
      final placeholders = List.filled(wordIds.length, '?').join(',');
      final results = await db.query(
        'word_meanings',
        where: 'word_id IN ($placeholders)',
        whereArgs: wordIds,
        orderBy: 'word_id ASC, definition_order ASC',
      );

      logger.dbQuery(
        table: 'word_meanings',
        where: 'word_id IN (${wordIds.length})',
        resultCount: results.length,
      );

      return results.map((map) => WordMeaning.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'word_meanings',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
