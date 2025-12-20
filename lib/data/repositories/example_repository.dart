import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/example_sentence.dart';

/// 例句仓库
/// 负责 example_sentences 表的查询
class ExampleRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取单词的所有例句
  Future<List<ExampleSentence>> getExampleSentences(int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'example_sentences',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      logger.dbQuery(
        table: 'example_sentences',
        where: 'word_id = $wordId',
        resultCount: results.length,
      );

      return results.map((map) => ExampleSentence.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'example_sentences',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
