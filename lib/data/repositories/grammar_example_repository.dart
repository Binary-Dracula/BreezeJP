import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar_example.dart';

class GrammarExampleRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取某语法的所有例句（按 sort_order 排序）
  Future<List<GrammarExample>> getExamplesByGrammarId(int grammarId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammar_examples',
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
        orderBy: 'sort_order ASC',
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

  /// 批量获取多个语法的例句
  Future<Map<int, List<GrammarExample>>> getExamplesByGrammarIds(
    List<int> grammarIds,
  ) async {
    if (grammarIds.isEmpty) return {};
    try {
      final db = await _db;
      final placeholders = List.filled(grammarIds.length, '?').join(',');
      final results = await db.query(
        'grammar_examples',
        where: 'grammar_id IN ($placeholders)',
        whereArgs: grammarIds,
        orderBy: 'grammar_id ASC, sort_order ASC',
      );

      final Map<int, List<GrammarExample>> grouped = {};
      for (final map in results) {
        final example = GrammarExample.fromMap(map);
        grouped.putIfAbsent(example.grammarId, () => []).add(example);
      }
      return grouped;
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
