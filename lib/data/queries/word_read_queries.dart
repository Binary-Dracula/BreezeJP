import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/word.dart';
import '../models/word_detail.dart';

final wordReadQueriesProvider = Provider<WordReadQueries>((ref) {
  final db = ref.read(databaseProvider);
  return WordReadQueries(db);
});

/// 单词 Read 查询层（2.0 — 基于新 words/word_details/word_examples 表）
class WordReadQueries {
  WordReadQueries(this._db);

  final Database _db;

  /// 获取单词的完整详情（JOIN words + word_details + word_examples + study_words）
  Future<WordDetail?> getWordDetail(String wordId, {int? userId}) async {
    try {
      // 1) 获取 word 基本信息
      final wordRows = await _db.query(
        'words',
        where: 'id = ?',
        whereArgs: [wordId],
        limit: 1,
      );
      if (wordRows.isEmpty) {
        logger.warning('单词不存在: $wordId');
        return null;
      }

      // 2) 获取 word_details
      final detailRows = await _db.query(
        'word_details',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: 1,
      );

      // 3) 获取 word_examples
      final exampleRows = await _db.query(
        'word_examples',
        where: 'word_id = ?',
        whereArgs: [wordId],
        orderBy: 'sort_order ASC',
      );

      // 4) 获取用户学习状态
      int? userState;
      if (userId != null) {
        final stateRows = await _db.query(
          'study_words',
          columns: ['user_state'],
          where: 'user_id = ? AND word_id = ?',
          whereArgs: [userId, wordId],
          limit: 1,
        );
        if (stateRows.isNotEmpty) {
          userState = stateRows.first['user_state'] as int?;
        }
      }

      logger.dbQuery(
        table: 'words + word_details + word_examples',
        where: 'word_id = $wordId',
        resultCount: 1,
      );

      return WordDetail.fromDbMaps(
        wordMap: wordRows.first,
        detailMap: detailRows.isNotEmpty ? detailRows.first : null,
        exampleMaps: exampleRows,
        userState: userState,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words (detail)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 批量获取单词详情
  Future<List<WordDetail>> getWordDetails(
    List<String> wordIds, {
    int? userId,
  }) async {
    if (wordIds.isEmpty) return [];

    final results = <WordDetail>[];
    for (final wordId in wordIds) {
      final detail = await getWordDetail(wordId, userId: userId);
      if (detail != null) results.add(detail);
    }
    return results;
  }

  /// 按 book_sort_order 从书中取下一批新词
  ///
  /// 返回 afterSort 之后的 limit 个单词的完整详情。
  /// 用于学习流：取当前进度之后的新词。
  Future<List<WordDetail>> getNextWordsInBook(
    String bookId, {
    required int afterSort,
    required int limit,
    int? userId,
  }) async {
    try {
      // 查 lesson_word_map → word_id，按 book_sort_order 排序
      final rows = await _db.rawQuery(
        '''
        SELECT lwm.word_id
        FROM lesson_word_map lwm
        WHERE lwm.book_id = ?
          AND lwm.book_sort_order > ?
        ORDER BY lwm.book_sort_order ASC
        LIMIT ?
        ''',
        [bookId, afterSort, limit],
      );

      logger.dbQuery(
        table: 'lesson_word_map',
        where: 'book_id=$bookId afterSort=$afterSort limit=$limit',
        resultCount: rows.length,
      );

      if (rows.isEmpty) return [];

      final wordIds =
          rows.map((r) => r['word_id'] as String).toList();
      return getWordDetails(wordIds, userId: userId);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'lesson_word_map + words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 搜索单词（按单词文本或 reading）
  Future<List<Word>> searchWords({required String keyword, int? limit}) async {
    try {
      final results = await _db.query(
        'words',
        where: 'word LIKE ? OR reading LIKE ? OR romaji LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
        orderBy: 'word ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'words',
        where: 'keyword = $keyword',
        resultCount: results.length,
      );

      return results.map((map) => Word.fromMap(map)).toList();
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

  /// 获取书中用户的最大 book_sort_order（用于确定学习进度游标）
  Future<int> getMaxLearnedSortOrder(String bookId, int userId) async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT MAX(lwm.book_sort_order) as max_sort
        FROM lesson_word_map lwm
        JOIN study_words sw ON lwm.word_id = sw.word_id AND sw.user_id = ?
        WHERE lwm.book_id = ?
          AND sw.user_state > 0
        ''',
        [userId, bookId],
      );

      if (rows.isEmpty || rows.first['max_sort'] == null) return 0;
      return rows.first['max_sort'] as int;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'lesson_word_map + study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
