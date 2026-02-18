import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar_meaning.dart';

class GrammarMeaningRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取某语法的所有义项（按 sort_order 排序）
  Future<List<GrammarMeaning>> getMeaningsByGrammarId(int grammarId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammar_meanings',
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
        orderBy: 'sort_order ASC',
      );

      logger.dbQuery(
        table: 'grammar_meanings',
        where: 'grammar_id = $grammarId',
        resultCount: results.length,
      );

      return results.map((map) => GrammarMeaning.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammar_meanings',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
