import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar.dart';

class GrammarRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<Grammar?> getGrammarById(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammars',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'grammars',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return Grammar.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<Grammar>> getGrammarsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final db = await _db;
      final placeholders = List.filled(ids.length, '?').join(',');
      final results = await db.query(
        'grammars',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );

      logger.dbQuery(
        table: 'grammars',
        where: 'id IN ($ids)',
        resultCount: results.length,
      );

      return results.map((map) => Grammar.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
