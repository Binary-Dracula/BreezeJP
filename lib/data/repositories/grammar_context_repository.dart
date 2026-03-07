import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar_context.dart';

class GrammarContextRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取某语法的所有上下文与限制条件
  Future<List<GrammarContext>> getContextsByGrammarId(int grammarId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammar_contexts',
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
      );

      logger.dbQuery(
        table: 'grammar_contexts',
        where: 'grammar_id = $grammarId',
        resultCount: results.length,
      );

      return results.map((map) => GrammarContext.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammar_contexts',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
