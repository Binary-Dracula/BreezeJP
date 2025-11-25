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
      logger.database(
        'SELECT',
        table: 'study_words',
        data: {'user_id': userId, 'word_id': wordId},
      );

      final db = await _db;
      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND word_id = ?',
        whereArgs: [userId, wordId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return StudyWord.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取学习记录失败', e, stackTrace);
      rethrow;
    }
  }

  /// 创建学习记录
  Future<int> createStudyWord(StudyWord studyWord) async {
    try {
      final data = studyWord.toMapForInsert();
      logger.database('INSERT', table: 'study_words', data: data);

      final db = await _db;
      final id = await db.insert('study_words', data);

      logger.info('创建学习记录成功: word_id=${studyWord.wordId}, id=$id');
      return id;
    } catch (e, stackTrace) {
      logger.error('创建学习记录失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新学习记录
  Future<void> updateStudyWord(StudyWord studyWord) async {
    try {
      logger.database('UPDATE', table: 'study_words', data: studyWord.toMap());

      final db = await _db;
      await db.update(
        'study_words',
        studyWord.toMap(),
        where: 'id = ?',
        whereArgs: [studyWord.id],
      );

      logger.info('更新学习记录成功: id=${studyWord.id}');
    } catch (e, stackTrace) {
      logger.error('更新学习记录失败', e, stackTrace);
      rethrow;
    }
  }

  /// 删除学习记录
  Future<void> deleteStudyWord(int id) async {
    try {
      logger.database('DELETE', table: 'study_words', data: {'id': id});

      final db = await _db;
      await db.delete('study_words', where: 'id = ?', whereArgs: [id]);

      logger.info('删除学习记录成功: id=$id');
    } catch (e, stackTrace) {
      logger.error('删除学习记录失败', e, stackTrace);
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
      logger.database(
        'SELECT',
        table: 'study_words',
        data: {'user_id': userId},
      );

      final db = await _db;
      final results = await db.query(
        'study_words',
        where: state != null ? 'user_id = ? AND user_state = ?' : 'user_id = ?',
        whereArgs: state != null ? [userId, state.value] : [userId],
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((map) => StudyWord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取用户学习记录失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取需要复习的单词
  Future<List<StudyWord>> getDueReviews(int userId, {int? limit}) async {
    try {
      logger.database('SELECT DUE REVIEWS', table: 'study_words');

      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND user_state = 1 AND next_review_at <= ?',
        whereArgs: [userId, now],
        orderBy: 'next_review_at ASC',
        limit: limit,
      );

      return results.map((map) => StudyWord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取待复习单词失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取新单词（未学习的）
  Future<List<StudyWord>> getNewWords(int userId, {int? limit}) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_words',
        where: 'user_id = ? AND user_state = 0',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
        limit: limit,
      );

      return results.map((map) => StudyWord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取新单词失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 统计方法 ====================

  /// 获取用户的学习统计
  Future<Map<String, dynamic>> getUserStatistics(int userId) async {
    try {
      logger.database('SELECT STATISTICS', table: 'study_words');

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

      return result.first;
    } catch (e, stackTrace) {
      logger.error('获取学习统计失败', e, stackTrace);
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

      return result.first['count'] as int;
    } catch (e, stackTrace) {
      logger.error('获取待复习数量失败', e, stackTrace);
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
      logger.info('记录答对: word_id=$wordId, 新间隔=$newInterval天');
    } catch (e, stackTrace) {
      logger.error('记录答对失败', e, stackTrace);
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
      logger.info('记录答错: word_id=$wordId, 新间隔=$newInterval天');
    } catch (e, stackTrace) {
      logger.error('记录答错失败', e, stackTrace);
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
      logger.info('标记为已掌握: word_id=$wordId');
    } catch (e, stackTrace) {
      logger.error('标记已掌握失败', e, stackTrace);
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
      logger.info('标记为忽略: word_id=$wordId');
    } catch (e, stackTrace) {
      logger.error('标记忽略失败', e, stackTrace);
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
      logger.info('重置学习进度: word_id=$wordId');
    } catch (e, stackTrace) {
      logger.error('重置学习进度失败', e, stackTrace);
      rethrow;
    }
  }
}
