import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_word.dart';

/// 学习进度数据仓库
/// 负责所有与用户学习进度相关的数据库操作
class StudyWordRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 获取用户对某个单词的学习记录
  Future<StudyWord?> getStudyWord(int userId, int wordId) async {
    try {
      final db = await _db;
      final whereClause = 'user_id = $userId AND word_id = $wordId';
      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND word_id = ?',
        whereArgs: [userId, wordId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'study_words',
        where: whereClause,
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

  /// 创建学习记录
  Future<int> createStudyWord(StudyWord studyWord) async {
    try {
      final data = studyWord.toMapForInsert();
      final db = await _db;
      final id = await db.insert('study_words', data);

      logger.dbInsert(
        table: 'study_words',
        id: id,
        keyFields: {'wordId': studyWord.wordId, 'userId': studyWord.userId},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// upsert 学习记录（学习中）
  Future<void> upsertLearned({
    required int userId,
    required int wordId,
    required int userState,
    required int nowEpochSeconds,
  }) async {
    try {
      final db = await _db;
      await db.rawInsert(
        '''
        INSERT INTO study_words (user_id, word_id, user_state, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id, word_id) DO UPDATE SET
          user_state = CASE 
            WHEN user_state = 2 THEN 2
            ELSE ?
          END,
          updated_at = ?
      ''',
        [
          userId,
          wordId,
          userState,
          nowEpochSeconds,
          nowEpochSeconds,
          userState,
          nowEpochSeconds,
        ],
      );

      logger.dbInsert(
        table: 'study_words',
        id: 0,
        keyFields: {
          'userId': userId,
          'wordId': wordId,
          'action': 'upsertLearned',
        },
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新学习记录
  Future<void> updateStudyWord(StudyWord studyWord) async {
    try {
      final db = await _db;
      final affectedRows = await db.update(
        'study_words',
        studyWord.toMap(),
        where: 'id = ?',
        whereArgs: [studyWord.id],
      );

      logger.dbUpdate(
        table: 'study_words',
        affectedRows: affectedRows,
        updatedFields: [
          'user_state',
          'interval',
          'ease_factor',
          'next_review_at',
        ],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除学习记录
  Future<void> deleteStudyWord(int id) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'study_words',
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.dbDelete(table: 'study_words', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
