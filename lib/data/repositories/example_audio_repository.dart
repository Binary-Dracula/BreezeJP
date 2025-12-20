import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/example_audio.dart';

/// 例句音频仓库
/// 负责 example_audio 表的查询
class ExampleAudioRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取例句音频
  Future<ExampleAudio?> getExampleAudio(int exampleId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'example_audio',
        where: 'example_id = ?',
        whereArgs: [exampleId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'example_audio',
        where: 'example_id = $exampleId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return ExampleAudio.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'example_audio',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 批量获取例句音频
  Future<List<ExampleAudio>> getExampleAudioByExampleIds(
    List<int> exampleIds,
  ) async {
    if (exampleIds.isEmpty) return [];

    try {
      final db = await _db;
      final placeholders = List.filled(exampleIds.length, '?').join(',');
      final results = await db.query(
        'example_audio',
        where: 'example_id IN ($placeholders)',
        whereArgs: exampleIds,
      );

      logger.dbQuery(
        table: 'example_audio',
        where: 'example_id IN (${exampleIds.length})',
        resultCount: results.length,
      );

      return results.map((map) => ExampleAudio.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'example_audio',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
