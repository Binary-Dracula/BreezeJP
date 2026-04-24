import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/study_word.dart';

final studyWordQueryProvider = Provider<StudyWordQuery>((ref) {
  final db = ref.read(databaseProvider);
  return StudyWordQuery(db);
});

/// StudyWord 查询层（只读）
class StudyWordQuery {
  StudyWordQuery(this._db);

  final Database _db;

  /// 获取用户在某本书中的所有学习记录
  Future<List<StudyWord>> getBookStudyWords(
    int userId,
    String bookId, {
    LearningStatus? state,
  }) async {
    try {
      final whereArgs = state != null
          ? [userId, bookId, state.value]
          : [userId, bookId];
      final whereClause = state != null
          ? 'user_id = ? AND book_id = ? AND user_state = ?'
          : 'user_id = ? AND book_id = ?';

      final results = await _db.query(
        'study_words',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'updated_at DESC',
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id=$userId book_id=$bookId state=${state?.value}',
        resultCount: results.length,
      );

      return results.map((map) => StudyWord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取用户对某本书中某个单词的学习记录
  Future<StudyWord?> getStudyWord(
    int userId,
    String wordId,
    String bookId,
  ) async {
    try {
      final results = await _db.query(
        'study_words',
        where: 'user_id = ? AND word_id = ? AND book_id = ?',
        whereArgs: [userId, wordId, bookId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id=$userId word_id=$wordId book_id=$bookId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return StudyWord.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取需要复习的单词（跨书汇总，按到期时间排序）
  Future<List<StudyWord>> getDueReviews(int userId, {int? limit}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final learningValue = LearningStatus.learning.value;

      final results = await _db.query(
        'study_words',
        where:
            'user_id = ? AND user_state = ? AND '
            '(next_review_at IS NULL OR next_review_at <= ?)',
        whereArgs: [userId, learningValue, now],
        orderBy: 'next_review_at ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id=$userId state=learning due<=$now',
        resultCount: results.length,
      );

      return results.map((map) => StudyWord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取待复习单词数量
  Future<int> getDueReviewCount(int userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final learningValue = LearningStatus.learning.value;

      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM study_words
        WHERE user_id = ? AND user_state = ?
          AND (next_review_at IS NULL OR next_review_at <= ?)
        ''',
        [userId, learningValue, now],
      );

      return result.first['count'] as int;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取某本书的学习统计（各状态数量）
  Future<Map<LearningStatus, int>> getBookStudyStats(
    int userId,
    String bookId,
  ) async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT user_state, COUNT(*) as count
        FROM study_words
        WHERE user_id = ? AND book_id = ?
        GROUP BY user_state
        ''',
        [userId, bookId],
      );

      final stats = <LearningStatus, int>{};
      for (final row in rows) {
        final status = LearningStatus.fromValue(row['user_state'] as int);
        stats[status] = row['count'] as int;
      }
      return stats;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
