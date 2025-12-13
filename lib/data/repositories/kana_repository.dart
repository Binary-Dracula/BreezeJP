import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/kana_letter.dart';
import '../models/kana_audio.dart';
import '../models/kana_example.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_log.dart';
import '../models/kana_stroke_order.dart';
import '../models/kana_detail.dart';

/// 五十音数据仓库
/// 负责所有与五十音图相关的数据库操作
class KanaRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 假名字母查询 ====================

  /// 获取所有假名字母
  Future<List<KanaLetter>> getAllKanaLetters() async {
    try {
      final db = await _db;
      final results = await db.query('kana_letters', orderBy: 'sort_index ASC');

      logger.dbQuery(
        table: 'kana_letters',
        where: null,
        resultCount: results.length,
      );

      return results.map((map) => KanaLetter.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据 ID 获取假名字母
  Future<KanaLetter?> getKanaLetterById(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_letters',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_letters',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return KanaLetter.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据类型获取假名字母
  /// type: basic/dakuten/handakuten/combo
  Future<List<KanaLetter>> getKanaLettersByType(String type) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_letters',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'sort_index ASC',
      );

      logger.dbQuery(
        table: 'kana_letters',
        where: 'type = $type',
        resultCount: results.length,
      );

      return results.map((map) => KanaLetter.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据行分组获取假名字母
  Future<List<KanaLetter>> getKanaLettersByGroup(String kanaGroup) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_letters',
        where: 'kana_group = ?',
        whereArgs: [kanaGroup],
        orderBy: 'sort_index ASC',
      );

      logger.dbQuery(
        table: 'kana_letters',
        where: 'kana_group = $kanaGroup',
        resultCount: results.length,
      );

      return results.map((map) => KanaLetter.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取所有行分组
  Future<List<String>> getAllKanaGroups() async {
    try {
      final db = await _db;
      final results = await db.rawQuery('''
        SELECT DISTINCT kana_group
        FROM kana_letters
        WHERE kana_group IS NOT NULL
        ORDER BY MIN(sort_index)
      ''');

      logger.dbQuery(
        table: 'kana_letters',
        where: 'DISTINCT kana_group',
        resultCount: results.length,
      );

      return results.map((map) => map['kana_group'] as String).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取所有假名类型（按排序顺序）
  Future<List<String>> getAllKanaTypes() async {
    try {
      final db = await _db;
      final results = await db.rawQuery('''
        SELECT DISTINCT type
        FROM kana_letters
        WHERE type IS NOT NULL
        GROUP BY type
        ORDER BY MIN(sort_index)
      ''');

      logger.dbQuery(
        table: 'kana_letters',
        where: 'DISTINCT type',
        resultCount: results.length,
      );

      return results.map((map) => map['type'] as String).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 假名音频 ====================

  /// 获取假名的音频
  Future<KanaAudio?> getKanaAudio(int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_audio',
        where: 'kana_id = ?',
        whereArgs: [kanaId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_audio',
        where: 'kana_id = $kanaId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return KanaAudio.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_audio',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 假名示例 ====================

  /// 获取假名的所有示例词汇
  Future<List<KanaExample>> getKanaExamples(int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_examples',
        where: 'kana_id = ?',
        whereArgs: [kanaId],
      );

      logger.dbQuery(
        table: 'kana_examples',
        where: 'kana_id = $kanaId',
        resultCount: results.length,
      );

      return results.map((map) => KanaExample.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_examples',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 学习状态 ====================

  /// 获取待复习的假名学习状态列表（学习中且到期）
  Future<List<KanaLearningState>> getDueReviewKana(int userId) async {
    try {
      final db = await _db;
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final results = await db.query(
        'kana_learning_state',
        where: '''
          user_id = ? 
          AND learning_status = ? 
          AND next_review_at <= ?
        ''',
        whereArgs: [userId, KanaLearningStatus.learning.index, nowSeconds],
        orderBy: 'next_review_at ASC',
      );

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, due review kana',
        resultCount: results.length,
      );

      return results.map((map) => KanaLearningState.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取待复习的假名数量
  Future<int> countDueKanaReviews(int userId) async {
    try {
      final db = await _db;
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt
        FROM kana_learning_state
        WHERE user_id = ?
          AND learning_status = ?
          AND next_review_at <= ?
      ''',
        [userId, KanaLearningStatus.learning.index, nowSeconds],
      );

      final count = (result.first['cnt'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, due review count',
        resultCount: 1,
      );

      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取或创建假名学习状态（UNIQUE: user_id + kana_id）
  /// 用于首次学习/复习前保证存在基础记录
  Future<KanaLearningState> getOrCreateLearningState(
    int userId,
    int kanaId,
  ) async {
    try {
      final db = await _db;
      final now = DateTime.now();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final nextReviewAt =
          now.add(const Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000;

      return await db.transaction((txn) async {
        // 1) 查询是否已存在
        final existing = await txn.query(
          'kana_learning_state',
          where: 'user_id = ? AND kana_id = ?',
          whereArgs: [userId, kanaId],
          limit: 1,
        );

        logger.dbQuery(
          table: 'kana_learning_state',
          where: 'user_id = $userId, kana_id = $kanaId',
          resultCount: existing.length,
        );

        if (existing.isNotEmpty) {
          return KanaLearningState.fromMap(existing.first);
        }

        // 2) 不存在则创建初始状态
        final insertMap = {
          'user_id': userId,
          'kana_id': kanaId,
          'learning_status': KanaLearningStatus.learning.index, // 1
          'next_review_at': nextReviewAt,
          'streak': 0,
          'total_reviews': 0,
          'fail_count': 0,
          'interval': 0,
          'ease_factor': 2.5,
          'stability': 0,
          'difficulty': 0,
          'created_at': nowSeconds,
          'updated_at': nowSeconds,
        };

        final id = await txn.insert('kana_learning_state', insertMap);
        logger.dbInsert(table: 'kana_learning_state', id: id);

        // 3) 返回最终模型
        return KanaLearningState.fromMap({...insertMap, 'id': id});
      });
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取假名的学习状态
  Future<KanaLearningState?> getKanaLearningState(
    int userId,
    int kanaId,
  ) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_learning_state',
        where: 'user_id = ? AND kana_id = ?',
        whereArgs: [userId, kanaId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, kana_id = $kanaId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return KanaLearningState.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取用户所有假名的学习状态
  Future<List<KanaLearningState>> getAllKanaLearningStates(int userId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_learning_state',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return results.map((map) => KanaLearningState.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 创建或更新假名学习状态
  Future<int> upsertKanaLearningState(KanaLearningState state) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final map = state.toInsertMap();
      map['updated_at'] = now;

      final result = await db.insert(
        'kana_learning_state',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.dbInsert(table: 'kana_learning_state', id: result);

      return result;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新假名学习状态
  Future<int> updateKanaLearningState(KanaLearningState state) async {
    try {
      final db = await _db;
      final result = await db.update(
        'kana_learning_state',
        state.toMap(),
        where: 'id = ?',
        whereArgs: [state.id],
      );

      logger.dbUpdate(table: 'kana_learning_state', affectedRows: result);

      return result;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 标记假名为已学习
  Future<void> markKanaAsLearned(int userId, int kanaId) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 检查是否已存在记录
      final existing = await getKanaLearningState(userId, kanaId);

      if (existing != null) {
        await db.update(
          'kana_learning_state',
          {
            'learning_status': KanaLearningStatus.mastered.index,
            'last_reviewed_at': now,
            'updated_at': now,
          },
          where: 'user_id = ? AND kana_id = ?',
          whereArgs: [userId, kanaId],
        );
        logger.dbUpdate(table: 'kana_learning_state', affectedRows: 1);
      } else {
        await db.insert('kana_learning_state', {
          'user_id': userId,
          'kana_id': kanaId,
          'learning_status': KanaLearningStatus.mastered.index,
          'last_reviewed_at': now,
          'streak': 0,
          'total_reviews': 0,
          'fail_count': 0,
          'interval': 0,
          'ease_factor': 2.5,
          'stability': 0,
          'difficulty': 0,
          'created_at': now,
          'updated_at': now,
        });
        logger.dbInsert(table: 'kana_learning_state', id: kanaId);
      }

      logger.info('假名标记为已学习: userId=$userId, kanaId=$kanaId');
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 学习日志 ====================

  /// 获取假名的学习日志
  Future<List<KanaLog>> getKanaLogs(int userId, int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_logs',
        where: 'user_id = ? AND kana_id = ?',
        whereArgs: [userId, kanaId],
        orderBy: 'created_at DESC',
      );

      logger.dbQuery(
        table: 'kana_logs',
        where: 'user_id = $userId, kana_id = $kanaId',
        resultCount: results.length,
      );

      return results.map((map) => KanaLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取用户所有学习日志
  Future<List<KanaLog>> getAllKanaLogs(int userId, {int? limit}) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_logs',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'kana_logs',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return results.map((map) => KanaLog.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 添加学习日志
  Future<int> addKanaLog(KanaLog log) async {
    try {
      final db = await _db;
      final result = await db.insert('kana_logs', log.toInsertMap());

      logger.dbInsert(table: 'kana_logs', id: result);

      return result;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 快速添加学习日志
  Future<int> addKanaLogQuick({
    required int userId,
    required int kanaId,
    required KanaLogType logType,
    int? rating,
    int algorithm = 1,
    double? intervalAfter,
    int? nextReviewAtAfter,
    double? easeFactorAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    String? questionType,
    int durationMs = 0,
  }) async {
    final log = KanaLog(
      id: 0,
      userId: userId,
      kanaId: kanaId,
      logType: logType,
      rating: rating,
      algorithm: algorithm,
      intervalAfter: intervalAfter,
      nextReviewAtAfter: nextReviewAtAfter,
      easeFactorAfter: easeFactorAfter,
      fsrsStabilityAfter: fsrsStabilityAfter,
      fsrsDifficultyAfter: fsrsDifficultyAfter,
      questionType: questionType,
      durationMs: durationMs,
    );
    final id = await addKanaLog(log);

    // 增量更新 daily_stats，仅在复习日志且存在评分时执行
    if (logType == KanaLogType.review && rating != null) {
      try {
        await _updateDailyStatsWithReview(
          userId: userId,
          kanaId: kanaId,
          rating: rating,
          intervalAfter: intervalAfter ?? 0,
          algorithm: algorithm,
          durationMs: durationMs,
        );
      } catch (e, stackTrace) {
        logger.dbError(
          operation: 'UPSERT',
          table: 'daily_stats',
          dbError: e,
          stackTrace: stackTrace,
        );
      }
    }

    return id;
  }

  /// 获取最近一次复习使用的题型（question_type/sub_type，兼容旧表）
  Future<String?> getLastKanaReviewQuestionType(int userId, int kanaId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '''
        SELECT question_type 
        FROM kana_logs 
        WHERE user_id = ? 
          AND kana_id = ? 
          AND log_type = ? 
          AND question_type IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1
        ''',
        [userId, kanaId, KanaLogType.review.index + 1],
      );

      if (result.isEmpty) return null;
      return result.first['question_type'] as String?;
    } catch (e, stackTrace) {
      // 兼容旧表没有 question_type 列时忽略错误
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs.question_type',
        dbError: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// 仅更新学习状态的更新时间
  Future<void> updateLearningTimestamp(int userId, int kanaId) async {
    try {
      final db = await _db;
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final affected = await db.update(
        'kana_learning_state',
        {'updated_at': nowSeconds},
        where: 'user_id = ? AND kana_id = ?',
        whereArgs: [userId, kanaId],
      );

      logger.dbUpdate(table: 'kana_learning_state', affectedRows: affected);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 插入学习日志（学习行为）
  Future<void> insertLearningLog({
    required int userId,
    required int kanaId,
    int durationMs = 0,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await db.insert('kana_logs', {
        'user_id': userId,
        'kana_id': kanaId,
        'log_type': 1, // 学习
        'rating': null,
        'algorithm': 1,
        'interval_after': null,
        'next_review_at_after': null,
        'ease_factor_after': null,
        'fsrs_stability_after': null,
        'fsrs_difficulty_after': null,
        'duration_ms': durationMs,
        'created_at': now,
      });

      logger.dbInsert(table: 'kana_logs', id: id);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 插入复习日志
  Future<void> insertReviewLog({
    required int userId,
    required int kanaId,
    required int rating,
    required int algorithm,
    required double intervalAfter,
    required int nextReviewAtAfter,
    required double easeFactorAfter,
    double? fsrsStabilityAfter,
    double? fsrsDifficultyAfter,
    String? questionType,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await db.insert('kana_logs', {
        'user_id': userId,
        'kana_id': kanaId,
        'log_type': KanaLogType.review.index + 1,
        'rating': rating,
        'algorithm': algorithm,
        'interval_after': intervalAfter,
        'next_review_at_after': nextReviewAtAfter,
        'ease_factor_after': easeFactorAfter,
        'fsrs_stability_after': fsrsStabilityAfter,
        'fsrs_difficulty_after': fsrsDifficultyAfter,
        'duration_ms': 0,
        'question_type': questionType,
        'created_at': now,
      });

      logger.dbInsert(table: 'kana_logs', id: id);

      try {
        await _updateDailyStatsWithReview(
          userId: userId,
          kanaId: kanaId,
          rating: rating,
          intervalAfter: intervalAfter,
          algorithm: algorithm,
          durationMs: 0,
        );
      } catch (e, stackTrace) {
        logger.dbError(
          operation: 'UPSERT',
          table: 'daily_stats',
          dbError: e,
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取假名的正确率（基于日志中的测验和复习记录）
  Future<double> getKanaAccuracy(int userId, int kanaId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN rating >= 2 THEN 1 ELSE 0 END) as correct_count
        FROM kana_logs
        WHERE user_id = ? AND kana_id = ? AND rating IS NOT NULL
      ''',
        [userId, kanaId],
      );

      logger.dbQuery(
        table: 'kana_logs',
        where: 'user_id = $userId, kana_id = $kanaId (accuracy)',
        resultCount: 1,
      );

      final total = result.first['total'] as int;
      if (total == 0) return 0.0;

      final correctCount = result.first['correct_count'] as int;
      return correctCount / total;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取用户学习日志统计
  Future<Map<String, int>> getKanaLogStats(int userId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN log_type = 1 THEN 1 ELSE 0 END) as first_learn_count,
          SUM(CASE WHEN log_type = 2 THEN 1 ELSE 0 END) as review_count,
          SUM(CASE WHEN log_type = 3 THEN 1 ELSE 0 END) as mastered_count,
          SUM(CASE WHEN log_type = 4 THEN 1 ELSE 0 END) as quiz_count,
          SUM(CASE WHEN log_type = 5 THEN 1 ELSE 0 END) as forgot_count
        FROM kana_logs
        WHERE user_id = ?
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'kana_logs',
        where: 'user_id = $userId (stats)',
        resultCount: 1,
      );

      return {
        'total': result.first['total'] as int? ?? 0,
        'firstLearnCount': result.first['first_learn_count'] as int? ?? 0,
        'reviewCount': result.first['review_count'] as int? ?? 0,
        'masteredCount': result.first['mastered_count'] as int? ?? 0,
        'quizCount': result.first['quiz_count'] as int? ?? 0,
        'forgotCount': result.first['forgot_count'] as int? ?? 0,
      };
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 笔顺数据 ====================

  /// 获取假名的笔顺数据
  Future<KanaStrokeOrder?> getKanaStrokeOrder(int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_stroke_order',
        where: 'kana_id = ?',
        whereArgs: [kanaId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_stroke_order',
        where: 'kana_id = $kanaId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return KanaStrokeOrder.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_stroke_order',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 组合查询 ====================

  /// 获取假名的完整详情
  Future<KanaDetail?> getKanaDetail(int userId, int kanaId) async {
    try {
      // 1. 获取假名基本信息
      final letter = await getKanaLetterById(kanaId);
      if (letter == null) {
        logger.warning('假名不存在: $kanaId');
        return null;
      }

      // 2. 获取音频
      final audio = await getKanaAudio(kanaId);

      // 3. 获取示例词汇
      final examples = await getKanaExamples(kanaId);

      // 4. 获取学习状态
      final learningState = await getKanaLearningState(userId, kanaId);

      // 5. 获取笔顺数据
      final strokeOrder = await getKanaStrokeOrder(kanaId);

      logger.info(
        '假名详情获取成功: ${letter.hiragana ?? letter.katakana} (${examples.length}个示例)',
      );

      return KanaDetail(
        letter: letter,
        audio: audio,
        examples: examples,
        learningState: learningState,
        strokeOrder: strokeOrder,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters (detail)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取所有假名及其学习状态（用于五十音表展示）
  Future<List<KanaLetterWithState>> getAllKanaLettersWithState(
    int userId,
  ) async {
    try {
      final db = await _db;
      final results = await db.rawQuery(
        '''
        SELECT 
          kl.*,
          kls.id as state_id,
          kls.user_id as state_user_id,
          kls.learning_status,
          kls.next_review_at,
          kls.last_reviewed_at,
          kls.streak,
          kls.total_reviews,
          kls.fail_count,
          kls.interval,
          kls.ease_factor,
          kls.stability,
          kls.difficulty,
          kls.created_at as state_created_at,
          kls.updated_at as state_updated_at
        FROM kana_letters kl
        LEFT JOIN kana_learning_state kls ON kl.id = kls.kana_id AND kls.user_id = ?
        ORDER BY kl.sort_index ASC
      ''',
        [userId],
      );

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'user_id = $userId',
        resultCount: results.length,
      );

      return results.map((map) {
        final letter = KanaLetter.fromMap(map);
        KanaLearningState? state;

        if (map['state_id'] != null) {
          state = KanaLearningState(
            id: map['state_id'] as int,
            userId: map['state_user_id'] as int,
            kanaId: letter.id,
            learningStatus:
                KanaLearningStatus.values[(map['learning_status'] as int? ?? 0)
                    .clamp(0, KanaLearningStatus.values.length - 1)],
            nextReviewAt: map['next_review_at'] as int?,
            lastReviewedAt: map['last_reviewed_at'] as int?,
            streak: map['streak'] as int? ?? 0,
            totalReviews: map['total_reviews'] as int? ?? 0,
            failCount: map['fail_count'] as int? ?? 0,
            interval: (map['interval'] as num?)?.toDouble() ?? 0,
            easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
            stability: (map['stability'] as num?)?.toDouble() ?? 0,
            difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0,
            createdAt: map['state_created_at'] as int?,
            updatedAt: map['state_updated_at'] as int?,
          );
        }

        return KanaLetterWithState(letter: letter, learningState: state);
      }).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters + kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==================== 统计查询 ====================

  /// 获取学习进度统计
  Future<Map<String, int>> getKanaLearningStats(int userId) async {
    try {
      final db = await _db;

      // 总假名数
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kana_letters',
      );
      final total = totalResult.first['count'] as int;

      // 已学习数（掌握）
      final learnedResult = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM kana_learning_state 
        WHERE user_id = ? AND learning_status = ?
        ''',
        [userId, KanaLearningStatus.mastered.index],
      );
      final learned = learnedResult.first['count'] as int;

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'user_id = $userId, stats',
        resultCount: 2,
      );

      return {'total': total, 'learned': learned, 'remaining': total - learned};
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取待复习的假名
  Future<List<KanaLetter>> getKanaDueForReview(int userId) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final results = await db.rawQuery(
        '''
        SELECT kl.*
        FROM kana_letters kl
        INNER JOIN kana_learning_state kls ON kl.id = kls.kana_id
        WHERE kls.user_id = ?
          AND kls.learning_status = ?
          AND (kls.next_review_at IS NULL OR kls.next_review_at <= ?)
        ORDER BY kls.next_review_at ASC
      ''',
        [userId, KanaLearningStatus.mastered.index, now],
      );

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'user_id = $userId, due for review',
        resultCount: results.length,
      );

      return results.map((map) => KanaLetter.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新假名复习结果（SRS 算法）
  Future<void> updateKanaReviewResult({
    required int userId,
    required int kanaId,
    required int rating,
    required double newInterval,
    required double newEaseFactor,
    required int nextReviewAt,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final existing = await getKanaLearningState(userId, kanaId);
      if (existing == null) {
        logger.warning('假名学习状态不存在: userId=$userId, kanaId=$kanaId');
        return;
      }

      final isCorrect = rating >= 2;
      final newStreak = isCorrect ? existing.streak + 1 : 0;
      final newFailCount = isCorrect
          ? existing.failCount
          : existing.failCount + 1;

      await db.update(
        'kana_learning_state',
        {
          'last_reviewed_at': now,
          'next_review_at': nextReviewAt,
          'streak': newStreak,
          'total_reviews': existing.totalReviews + 1,
          'fail_count': newFailCount,
          'interval': newInterval,
          'ease_factor': newEaseFactor,
          'updated_at': now,
        },
        where: 'user_id = ? AND kana_id = ?',
        whereArgs: [userId, kanaId],
      );

      logger.dbUpdate(table: 'kana_learning_state', affectedRows: 1);
      logger.info(
        '假名复习结果更新: userId=$userId, kanaId=$kanaId, rating=$rating, interval=$newInterval',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'kana_learning_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _updateDailyStatsWithReview({
    required int userId,
    required int kanaId,
    required int rating,
    required double intervalAfter,
    required int algorithm,
    int durationMs = 0,
  }) async {
    final db = await _db;
    final dateStr = _formatDate(DateTime.now());
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wrongFlag = rating == 1 ? 1 : 0;

    final existing = await db.query(
      'daily_stats',
      columns: [
        'id',
        'review_count',
        'rating_avg',
        'new_interval_avg',
        'wrong_ratio',
        'total_time_ms',
        'algorithm',
        'unique_kana_reviewed_count',
        'first_review_at',
        'last_review_at',
        'learning_quality_score',
      ],
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, dateStr],
      limit: 1,
    );

    if (existing.isEmpty) {
      final id = await db.insert('daily_stats', {
        'user_id': userId,
        'date': dateStr,
        'review_count': 1,
        'rating_avg': rating.toDouble(),
        'new_interval_avg': intervalAfter,
        'wrong_ratio': wrongFlag.toDouble(),
        'total_time_ms': durationMs,
        'algorithm': algorithm,
        'unique_kana_reviewed_count': 1,
        'first_review_at': now,
        'last_review_at': now,
        'learning_quality_score': rating.toDouble(),
      });
      logger.dbInsert(
        table: 'daily_stats',
        id: id,
        keyFields: {'user_id': userId, 'date': dateStr},
      );
      return;
    }

    final row = existing.first;
    final currentCount = (row['review_count'] as int?) ?? 0;
    final currentRatingAvg = (row['rating_avg'] as num?)?.toDouble() ?? 0;
    final currentIntervalAvg =
        (row['new_interval_avg'] as num?)?.toDouble() ?? 0;
    final currentWrongRatio = (row['wrong_ratio'] as num?)?.toDouble() ?? 0;
    final currentTotalTime = row['total_time_ms'] as int? ?? 0;
    final currentUniqueKana = row['unique_kana_reviewed_count'] as int? ?? 0;
    final currentFirstReviewAt = row['first_review_at'] as int?;
    final currentLearningQuality =
        (row['learning_quality_score'] as num?)?.toDouble() ?? currentRatingAvg;

    final newCount = currentCount + 1;
    final newRatingAvg =
        ((currentRatingAvg * currentCount) + rating) / newCount;
    final newIntervalAvg =
        ((currentIntervalAvg * currentCount) + intervalAfter) / newCount;
    final newWrongRatio =
        ((currentWrongRatio * currentCount) + wrongFlag) / newCount;
    final newTotalTime = currentTotalTime + durationMs;
    final newLearningQuality =
        ((currentLearningQuality * currentCount) + rating) / newCount;

    // 判断今日是否首次复习该假名
    final kanaReviewedToday = await db.query(
      'kana_logs',
      columns: ['id'],
      where:
          'user_id = ? AND kana_id = ? AND date(created_at, \'unixepoch\') = ? AND log_type = ?',
      whereArgs: [userId, kanaId, dateStr, KanaLogType.review.index + 1],
      limit: 1,
    );
    final isNewKanaToday = kanaReviewedToday.isEmpty;
    final updatedUniqueKana = isNewKanaToday
        ? currentUniqueKana + 1
        : currentUniqueKana;

    final affectedRows = await db.update(
      'daily_stats',
      {
        'review_count': newCount,
        'rating_avg': newRatingAvg,
        'new_interval_avg': newIntervalAvg,
        'wrong_ratio': newWrongRatio,
        'total_time_ms': newTotalTime,
        'algorithm': algorithm,
        'unique_kana_reviewed_count': updatedUniqueKana,
        'first_review_at': currentFirstReviewAt ?? now,
        'last_review_at': now,
        'learning_quality_score': newLearningQuality,
      },
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, dateStr],
    );

    logger.dbUpdate(
      table: 'daily_stats',
      affectedRows: affectedRows,
      updatedFields: [
        'review_count',
        'rating_avg',
        'new_interval_avg',
        'wrong_ratio',
        'total_time_ms',
        'algorithm',
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
