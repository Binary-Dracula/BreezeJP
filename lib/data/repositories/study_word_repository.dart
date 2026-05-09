import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/study_word.dart';

/// 学习进度数据仓库
/// 负责所有与用户学习进度相关的数据库操作（2.0 — 唯一键为 user_id+word_id+book_id）
class StudyWordRepository {
  StudyWordRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  // ==================== 基础 CRUD ====================

  /// 获取用户对某本书中某个单词的学习记录
  Future<StudyWord?> getStudyWord(
    int userId,
    String wordId,
    String bookId,
  ) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND word_id = ? AND book_id = ?',
        whereArgs: [userId, wordId, bookId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id=$userId AND word_id=$wordId AND book_id=$bookId',
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

  /// 插入新学习记录
  Future<int> createStudyWord(StudyWord studyWord) async {
    try {
      final db = await _db;
      final id = await db.insert('study_words', studyWord.toMapForInsert());

      logger.dbInsert(
        table: 'study_words',
        id: id,
        keyFields: {
          'wordId': studyWord.wordId,
          'bookId': studyWord.bookId,
          'userId': studyWord.userId,
        },
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

  /// 插入新学习记录（忽略唯一冲突）
  Future<int> createStudyWordIgnoreConflict(StudyWord studyWord) async {
    try {
      final db = await _db;
      final id = await db.insert(
        'study_words',
        studyWord.toMapForInsert(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      logger.dbInsert(
        table: 'study_words',
        id: id,
        keyFields: {
          'wordId': studyWord.wordId,
          'bookId': studyWord.bookId,
          'userId': studyWord.userId,
        },
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

  /// 按唯一键保存学习记录（存在则覆盖）
  Future<void> saveStudyWord(StudyWord studyWord) async {
    try {
      final db = await _db;
      final map = studyWord.toMapForInsert();
      await db.insert(
        'study_words',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.dbInsert(
        table: 'study_words',
        id: studyWord.id,
        keyFields: {
          'wordId': studyWord.wordId,
          'bookId': studyWord.bookId,
          'userId': studyWord.userId,
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
        updatedFields: const [
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

  /// 删除单条记录
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

  /// 批量重置某用户所有 learning 记录的 SRS 参数（算法切换时调用）
  Future<void> resetAlgorithmSrsData(int userId) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final affected = await db.rawUpdate(
        '''
        UPDATE study_words
        SET ease_factor = 2.5,
            stability   = 0,
            difficulty  = 0,
            interval    = 0,
            streak      = 0,
            next_review_at = ?,
            updated_at  = ?
        WHERE user_id = ? AND user_state = ?
        ''',
        [now + 60, now, userId, 1], // 1 = learning
      );

      logger.dbUpdate(
        table: 'study_words',
        affectedRows: affected,
        updatedFields: const [
          'ease_factor',
          'stability',
          'difficulty',
          'interval',
          'streak',
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

  /// 删除某本书的所有学习记录
  Future<void> deleteAllByBook(int userId, String bookId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'study_words',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
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

  /// 获取某用户的所有学习记录
  Future<List<StudyWord>> getAllByUser(int userId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_words',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return results.map(StudyWord.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT ALL',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除某用户的所有学习记录
  Future<void> deleteAllByUser(int userId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'study_words',
        where: 'user_id = ?',
        whereArgs: [userId],
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

  /// 按唯一键删除学习记录
  Future<void> deleteStudyWordByUniqueKey(
    int userId,
    String wordId,
    String bookId,
  ) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'study_words',
        where: 'user_id = ? AND word_id = ? AND book_id = ?',
        whereArgs: [userId, wordId, bookId],
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
