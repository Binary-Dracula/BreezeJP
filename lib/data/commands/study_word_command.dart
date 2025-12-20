import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../commands/daily_stat_command.dart';
import '../db/app_database.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

final studyWordCommandProvider = Provider<StudyWordCommand>((ref) {
  return StudyWordCommand(ref);
});

/// StudyWord 行为命令层（状态变更 / SRS）
class StudyWordCommand {
  StudyWordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);
  DailyStatCommand get _dailyStatCommand =>
      ref.read(dailyStatCommandProvider);
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 记录复习结果（答对）
  Future<void> submitCorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
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

      await _repo.updateStudyWord(updated);
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
  Future<void> submitIncorrectReview(
    int userId,
    int wordId, {
    required double newInterval,
    required double newEaseFactor,
    double? newStability,
    double? newDifficulty,
  }) async {
    try {
      final studyWord = await _repo.getStudyWord(userId, wordId);
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
        streak: 0,
        totalReviews: studyWord.totalReviews + 1,
        failCount: studyWord.failCount + 1,
        updatedAt: now,
      );

      await _repo.updateStudyWord(updated);
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
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.mastered,
        updatedAt: DateTime.now(),
      );

      await _repo.updateStudyWord(updated);
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
      final studyWord = await _repo.getStudyWord(userId, wordId);
      if (studyWord == null) {
        throw Exception('学习记录不存在');
      }

      final updated = studyWord.copyWith(
        userState: UserWordState.ignored,
        updatedAt: DateTime.now(),
      );

      await _repo.updateStudyWord(updated);
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
      final studyWord = await _repo.getStudyWord(userId, wordId);
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

      await _repo.updateStudyWord(updated);
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

  /// 标记单词为学习中（user_state = 1）
  /// 如果记录不存在则创建，存在则更新
  Future<void> markAsLearned({required int userId, required int wordId}) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db.rawInsert(
        '''
        INSERT INTO study_words (user_id, word_id, user_state, created_at, updated_at)
        VALUES (?, ?, 1, ?, ?)
        ON CONFLICT(user_id, word_id) DO UPDATE SET
          user_state = CASE 
            WHEN user_state = 2 THEN 2
            ELSE 1 
          END,
          updated_at = ?
      ''',
        [userId, wordId, now, now, now],
      );

      logger.dbInsert(
        table: 'study_words',
        id: 0,
        keyFields: {
          'userId': userId,
          'wordId': wordId,
          'action': 'markAsLearned',
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

  /// 更新每日统计（学习会话结束）
  Future<void> updateDailyStats({
    required int userId,
    required int learnedCount,
    required int durationMs,
  }) async {
    await _dailyStatCommand.updateDailyStats(
      userId: userId,
      learnedCount: learnedCount,
      durationMs: durationMs,
    );
  }
}
