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

  // ==================== 查询方法 ====================

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

  // ==================== 统计方法 ====================

  /// 获取用户的学习统计
  Future<Map<String, dynamic>> getUserStatistics(int userId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_words,
          SUM(CASE WHEN user_state = 0 THEN 1 ELSE 0 END) as new_words,
          SUM(CASE WHEN user_state = 1 THEN 1 ELSE 0 END) as learning_words,
          SUM(CASE WHEN user_state = 2 THEN 1 ELSE 0 END) as mastered_words,
          SUM(CASE WHEN user_state = 3 THEN 1 ELSE 0 END) as ignored_words,
          SUM(total_reviews) as total_reviews,
          AVG(ease_factor) as avg_ease_factor,
          SUM(fail_count) as total_fails
        FROM study_words
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'study_words',
        where: 'user_id = $userId (statistics)',
        resultCount: 1,
      );

      return result.first;
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

  // ==================== SRS 更新方法 ====================

  /// 记录复习结果（答对）
  Future<void> recordCorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    try {
      final studyWord = await getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final now = DateTime.now();
      final nextReview = now.add(Duration(days: newInterval.ceil()));

      final updated = studyWord.copyWith(
        userState: UserWordState.learning,
        lastReviewedAt: now,
        nextReviewAt: nextReview,
        interval: newInterval,
        easeFactor: newEaseFactor,
        stability: newStability ?? studyWord.stability,
        difficulty: newDifficulty ?? studyWord.difficulty,
        streak: studyWord.streak + 1,
        totalReviews: studyWord.totalReviews + 1,
        updatedAt: now,
      );

      await updateStudyWord(updated);
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

  /// 记录复习结果（答错）
  Future<void> recordIncorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    try {
      final studyWord = await getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final now = DateTime.now();
      final nextReview = now.add(Duration(days: newInterval.ceil()));

      final updated = studyWord.copyWith(
        userState: UserWordState.learning,
        lastReviewedAt: now,
        nextReviewAt: nextReview,
        interval: newInterval,
        easeFactor: newEaseFactor,
        stability: newStability ?? studyWord.stability,
        difficulty: newDifficulty ?? studyWord.difficulty,
        streak: 0, // 重置连续答对次数
        totalReviews: studyWord.totalReviews + 1,
        failCount: studyWord.failCount + 1,
        updatedAt: now,
      );

      await updateStudyWord(updated);
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

  /// 标记单词为已掌握
  Future<void> markAsMastered(int userId, int wordId) async {
    try {
      final studyWord = await getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.mastered,
        updatedAt: DateTime.now(),
      );

      await updateStudyWord(updated);
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

  /// 标记单词为忽略
  Future<void> markAsIgnored(int userId, int wordId) async {
    try {
      final studyWord = await getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.ignored,
        updatedAt: DateTime.now(),
      );

      await updateStudyWord(updated);
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

  /// 重置单词学习进度
  Future<void> resetProgress(int userId, int wordId) async {
    try {
      final studyWord = await getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final now = DateTime.now();
      final updated = studyWord.copyWith(
        userState: UserWordState.newWord,
        nextReviewAt: null,
        lastReviewedAt: null,
        interval: 0,
        easeFactor: 2.5,
        stability: 0,
        difficulty: 0,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        updatedAt: now,
      );

      await updateStudyWord(updated);
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
}
