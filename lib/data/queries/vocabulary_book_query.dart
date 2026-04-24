import 'package:sqflite/sqflite.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/read/vocabulary_book_item.dart';

/// 单词本查询层（只读，2.0 — 对齐新 words 表）
/// 联表查询 study_words + words
class VocabularyBookQuery {
  VocabularyBookQuery(this._db);

  final Database _db;

  /// 获取单词本列表项（分页 + 按状态筛选 + 可选搜索）
  Future<List<VocabularyBookItem>> getVocabularyBookItems({
    required int userId,
    required LearningStatus status,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    try {
      final whereArgs = <Object>[userId, status.value];
      var searchClause = '';

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final keyword = '%${searchQuery.trim()}%';
        searchClause = '''
          AND (w.word LIKE ? OR w.reading LIKE ? OR w.primary_meaning LIKE ? OR w.romaji LIKE ?)
        ''';
        whereArgs.addAll([keyword, keyword, keyword, keyword]);
      }

      final sql =
          '''
        SELECT
          sw.id AS study_word_id,
          sw.word_id,
          sw.book_id,
          w.word,
          w.reading,
          w.jlpt_level,
          w.part_of_speech,
          w.primary_meaning,
          w.has_audio,
          sw.user_state,
          sw.updated_at
        FROM study_words sw
        INNER JOIN words w ON sw.word_id = w.id
        WHERE sw.user_id = ? AND sw.user_state = ?
        $searchClause
        ORDER BY sw.updated_at DESC
        LIMIT $limit OFFSET $offset
      ''';

      final results = await _db.rawQuery(sql, whereArgs);

      logger.dbQuery(
        table: 'study_words + words',
        where:
            'user_id=$userId, user_state=${status.name}, search=$searchQuery',
        resultCount: results.length,
      );

      return results.map((row) => VocabularyBookItem.fromMap(row)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'vocabulary_book (join)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取各状态的单词数量
  Future<Map<LearningStatus, int>> getStatusCounts({
    required int userId,
    String? searchQuery,
  }) async {
    try {
      final whereArgs = <Object>[
        userId,
        LearningStatus.learning.value,
        LearningStatus.mastered.value,
        LearningStatus.ignored.value,
      ];
      var searchClause = '';

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final keyword = '%${searchQuery.trim()}%';
        searchClause = '''
          AND (w.word LIKE ? OR w.reading LIKE ? OR w.primary_meaning LIKE ? OR w.romaji LIKE ?)
        ''';
        whereArgs.addAll([keyword, keyword, keyword, keyword]);
      }

      final sql =
          '''
        SELECT sw.user_state, COUNT(*) AS count
        FROM study_words sw
        INNER JOIN words w ON sw.word_id = w.id
        WHERE sw.user_id = ?
          AND sw.user_state IN (?, ?, ?)
          $searchClause
        GROUP BY sw.user_state
      ''';

      final results = await _db.rawQuery(sql, whereArgs);

      logger.dbQuery(
        table: 'study_words (status counts)',
        where: 'user_id=$userId, search=$searchQuery',
        resultCount: results.length,
      );

      final counts = <LearningStatus, int>{
        LearningStatus.learning: 0,
        LearningStatus.mastered: 0,
        LearningStatus.ignored: 0,
      };

      for (final row in results) {
        final status = LearningStatus.fromValue(row['user_state'] as int);
        counts[status] = row['count'] as int;
      }

      return counts;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words (status counts)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
