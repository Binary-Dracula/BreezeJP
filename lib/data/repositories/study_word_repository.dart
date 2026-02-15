import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_word.dart';

/// 学习进度数据仓库
/// 负责所有与用户学习进度相关的数据库操作
class StudyWordRepository {
  StudyWordRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  /// 获取数据库实例
  Future<Database> get _db async => await _dbProvider();

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

  /// 创建学习记录（忽略唯一冲突）
  Future<int> createStudyWordIgnoreConflict(StudyWord studyWord) async {
    try {
      final data = studyWord.toMapForInsert();
      final db = await _db;
      final id = await db.insert(
        'study_words',
        data,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

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
          'next_review_at',
          'last_reviewed_at',
          'interval',
          'ease_factor',
          'stability',
          'difficulty',
          'streak',
          'total_reviews',
          'fail_count',
          'updated_at',
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
