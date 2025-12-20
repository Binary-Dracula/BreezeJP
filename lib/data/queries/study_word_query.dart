import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_word.dart';

final studyWordQueryProvider = Provider<StudyWordQuery>((ref) {
  return StudyWordQuery();
});

/// StudyWord 查询层（只读）
class StudyWordQuery {
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 获取用户的所有学习记录
  Future<List<StudyWord>> getUserStudyWords(
    int userId, {
    UserWordState? state,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _db;
      final whereClause = state != null
          ? 'user_id = $userId AND user_state = ${state.value}'
          : 'user_id = $userId';
      final results = await db.query(
        'study_words',
        where: state != null ? 'user_id = ? AND user_state = ?' : 'user_id = ?',
        whereArgs: state != null ? [userId, state.value] : [userId],
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );

      logger.dbQuery(
        table: 'study_words',
        where: whereClause,
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

  /// 获取需要复习的单词
  Future<List<StudyWord>> getDueReviews(int userId, {int? limit}) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final whereClause =
          'user_id = $userId AND user_state = 1 AND next_review_at <= $now';

      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND user_state = 1 AND next_review_at <= ?',
        whereArgs: [userId, now],
        orderBy: 'next_review_at ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'study_words',
        where: whereClause,
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

  /// 获取新单词（未学习的）
  Future<List<StudyWord>> getNewWords(int userId, {int? limit}) async {
    try {
      final db = await _db;
      final whereClause = 'user_id = $userId AND user_state = 0';
      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND user_state = 0',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'study_words',
        where: whereClause,
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
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM study_words
        WHERE user_id = ? AND user_state = 1 AND next_review_at <= ?
      ''',
        [userId, now],
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id = $userId AND user_state = 1 (due count)',
        resultCount: 1,
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
}
