import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar_example.dart';

class GrammarExampleRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<List<GrammarExample>> getExamplesByGrammarId(int grammarId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammar_examples',
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
        orderBy: 'id ASC',
      );

      logger.dbQuery(
        table: 'grammar_examples',
        where: 'grammar_id = $grammarId',
        resultCount: results.length,
      );

      return results.map((map) => GrammarExample.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammar_examples',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
