import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/read/jlpt_level_count.dart';

final wordAnalyticsProvider = Provider<WordAnalytics>((ref) {
  return WordAnalytics();
});

/// 单词统计分析
class WordAnalytics {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取各 JLPT 等级的单词数量
  Future<List<JlptLevelCount>> getWordCountByLevel() async {
    try {
      final db = await _db;
      final results = await db.rawQuery('''
        SELECT jlpt_level, COUNT(*) as count
        FROM words
        WHERE jlpt_level IS NOT NULL
        GROUP BY jlpt_level
        ORDER BY jlpt_level DESC
      ''');

      logger.dbQuery(
        table: 'words',
        where: 'GROUP BY jlpt_level',
        resultCount: results.length,
      );

      return results
          .map((row) => JlptLevelCount.fromMap(row))
          .toList();
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
