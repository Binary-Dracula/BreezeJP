import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/grammar_example.dart';

class GrammarExampleRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取某义项的所有例句（按 sort_order 排序）
  Future<List<GrammarExample>> getExamplesByMeaningId(int meaningId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'grammar_examples',
        where: 'meaning_id = ?',
        whereArgs: [meaningId],
        orderBy: 'sort_order ASC',
      );

      logger.dbQuery(
        table: 'grammar_examples',
        where: 'meaning_id = $meaningId',
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

  /// 批量获取多个义项的例句（减少 N+1 查询）
  Future<Map<int, List<GrammarExample>>> getExamplesByMeaningIds(
    List<int> meaningIds,
  ) async {
    if (meaningIds.isEmpty) return {};
    try {
      final db = await _db;
      final placeholders = List.filled(meaningIds.length, '?').join(',');
      final results = await db.query(
        'grammar_examples',
        where: 'meaning_id IN ($placeholders)',
        whereArgs: meaningIds,
        orderBy: 'meaning_id ASC, sort_order ASC',
      );

      final Map<int, List<GrammarExample>> grouped = {};
      for (final map in results) {
        final example = GrammarExample.fromMap(map);
        grouped.putIfAbsent(example.meaningId, () => []).add(example);
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
