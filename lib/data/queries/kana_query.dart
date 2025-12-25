import 'package:sqflite/sqflite.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/kana_audio.dart';
import '../models/kana_example.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_letter.dart';
import '../models/kana_log.dart';
import '../models/kana_stroke_order.dart';
import '../models/read/kana_accuracy.dart';
import '../models/read/kana_detail.dart';
import '../models/read/kana_group_item.dart';
import '../models/read/kana_learning_stats.dart';
import '../models/read/kana_log_item.dart';
import '../models/read/kana_type_item.dart';

/// Kana 相关只读查询的辅助类。
///
/// 统一管理 `kana_*` 表的关联、过滤与聚合查询，并返回类型化模型对象。
/// 每个方法都会记录查询日志，发生数据库错误时会记录并重新抛出，便于调用方统一处理。
class KanaQuery {
  KanaQuery(this._db);

  final Database _db;

  /// 从 `kana_letters` 中返回去重后的分组名称，
  /// 并按每个分组内最早的 `sort_index` 排序。
  Future<List<KanaGroupItem>> getAllKanaGroups() async {
    try {
      final results = await _db.rawQuery('''
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

      return results
          .map(
            (map) => KanaGroupItem(group: map['kana_group'] as String),
          )
          .toList();
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

  /// 从 `kana_letters` 中返回去重后的类型，
  /// 并按每个类型内最早的 `sort_index` 排序。
  Future<List<KanaTypeItem>> getAllKanaTypes() async {
    try {
      final results = await _db.rawQuery('''
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

      return results
          .map(
            (map) => KanaTypeItem(type: map['type'] as String),
          )
          .toList();
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

  /// 返回用户当前到期需要复习的学习状态记录。
  ///
  /// 到期条件：`learning_status` 为 `learning`，
  /// 且 `next_review_at` 小于等于当前时间戳（秒）。
  Future<List<KanaLearningState>> getDueReviewKana(int userId) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final results = await _db.query(
        'kana_learning_state',
        where: '''
          user_id = ? 
          AND learning_status = ? 
          AND next_review_at <= ?
        ''',
        whereArgs: [userId, LearningStatus.learning.value, nowSeconds],
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

  /// 统计用户到期需要复习的学习状态数量。
  ///
  /// 规则同 [getDueReviewKana]。
  Future<int> countDueKanaReviews(int userId) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt
        FROM kana_learning_state
        WHERE user_id = ?
          AND learning_status = ?
          AND next_review_at <= ?
      ''',
        [userId, LearningStatus.learning.value, nowSeconds],
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

  /// 返回用户到期需要复习的 Kana 字符。
  ///
  /// 关联 `kana_letters` 与 `kana_learning_state`，
  /// 过滤条件为 `learning_status = learning`，
  /// 且 `next_review_at` 不为空并已到期。
  Future<List<KanaLetter>> getKanaDueForReview(int userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final results = await _db.rawQuery(
        '''
        SELECT kl.*
        FROM kana_letters kl
        INNER JOIN kana_learning_state kls ON kl.id = kls.kana_id
        WHERE kls.user_id = ?
          AND kls.learning_status = ?
          AND kls.next_review_at IS NOT NULL
          AND kls.next_review_at <= ?
        ORDER BY kls.next_review_at ASC
      ''',
        [userId, LearningStatus.learning.value, now],
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

  /// 返回指定用户与 Kana 的日志列表，按时间倒序。
  Future<List<KanaLogItem>> getKanaLogs(int userId, int kanaId) async {
    try {
      final results = await _db.query(
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

      return results
          .map((map) => KanaLogItem.fromLog(KanaLog.fromMap(map)))
          .toList();
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

  /// 返回用户的日志列表，按时间倒序，可选限制数量。
  Future<List<KanaLogItem>> getAllKanaLogs(int userId, {int? limit}) async {
    try {
      final results = await _db.query(
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

      return results
          .map((map) => KanaLogItem.fromLog(KanaLog.fromMap(map)))
          .toList();
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

  /// 返回用户针对指定 Kana 最近一次复习的题型。
  ///
  /// 仅统计 `log_type = review` 且 `question_type` 非空的日志。
  /// 若未找到记录或旧表结构缺少 `question_type` 列，则返回 null。
  Future<String?> getLastKanaReviewQuestionType(int userId, int kanaId) async {
    try {
      final result = await _db.rawQuery(
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
      // ignore errors for legacy table without question_type
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_logs.question_type',
        dbError: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// 基于日志评分统计用户在指定 Kana 上的正确率。
  ///
  /// 以 `rating >= 2` 视为正确，忽略 `rating` 为空的记录。
  Future<KanaAccuracy> getKanaAccuracy(int userId, int kanaId) async {
    try {
      final result = await _db.rawQuery(
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
      final correctCount = result.first['correct_count'] as int? ?? 0;
      final accuracy = total == 0 ? 0.0 : correctCount / total;

      return KanaAccuracy(
        total: total,
        correct: correctCount,
        accuracy: accuracy,
      );
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

  /// 汇总用户在所有 Kana 上的日志类型统计数量。
  Future<KanaLogStats> getKanaLogStats(int userId) async {
    try {
      final result = await _db.rawQuery(
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

      return KanaLogStats(
        total: result.first['total'] as int? ?? 0,
        firstLearnCount: result.first['first_learn_count'] as int? ?? 0,
        reviewCount: result.first['review_count'] as int? ?? 0,
        masteredCount: result.first['mastered_count'] as int? ?? 0,
        quizCount: result.first['quiz_count'] as int? ?? 0,
        forgotCount: result.first['forgot_count'] as int? ?? 0,
      );
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

  /// 加载指定 Kana 的完整详情，包括关联数据。
  ///
  /// 若 Kana 字符不存在则返回 null。
  Future<KanaDetail?> getKanaDetail(int userId, int kanaId) async {
    try {
      final letter = await getKanaLetterById(kanaId);
      if (letter == null) {
        logger.warning('Kana not found: $kanaId');
        return null;
      }

      final audio = await getKanaAudio(kanaId);
      final examples = await _getKanaExamples(kanaId);
      final learningState = await getKanaLearningState(userId, kanaId);
      final strokeOrder = await getKanaStrokeOrder(kanaId);

      logger.info(
        'Kana detail loaded: ${letter.hiragana ?? letter.katakana} (${examples.length} examples)',
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

  /// 返回全部 Kana 字符以及对应的用户学习状态（若存在）。
  ///
  /// 使用左连接，确保即使用户尚无学习状态记录也会返回该字符。
  Future<List<KanaLetterWithState>> getAllKanaLettersWithState(
    int userId,
  ) async {
    try {
      final results = await _db.rawQuery(
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
                LearningStatus.values[(map['learning_status'] as int? ?? 0)
                    .clamp(0, LearningStatus.values.length - 1)],
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

  /// 返回用户的学习统计：总数、已学、剩余。
  Future<KanaLearningStats> getKanaLearningStats(int userId) async {
    try {
      final totalResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM kana_letters',
      );
      final total = totalResult.first['count'] as int;

      final learnedResult = await _db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM kana_learning_state 
        WHERE user_id = ? AND learning_status IN (?, ?)
        ''',
        [
          userId,
          LearningStatus.learning.value,
          LearningStatus.mastered.value,
        ],
      );
      final learned = learnedResult.first['count'] as int;

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'user_id = $userId, stats',
        resultCount: 2,
      );

      return KanaLearningStats(
        total: total,
        learned: learned,
        remaining: total - learned,
      );
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

  /// 返回指定 Kana 的音频记录（如存在）。
  Future<KanaAudio?> getKanaAudio(int kanaId) async {
    try {
      final results = await _db.query(
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

  /// 返回指定 Kana 的笔顺记录（如存在）。
  Future<KanaStrokeOrder?> getKanaStrokeOrder(int kanaId) async {
    try {
      final results = await _db.query(
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

  /// 根据 id 返回单个 Kana 字符，未找到则返回 null。
  Future<KanaLetter?> getKanaLetterById(int kanaId) async {
    try {
      final results = await _db.query(
        'kana_letters',
        where: 'id = ?',
        whereArgs: [kanaId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_letters',
        where: 'id = $kanaId',
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

  /// 返回用户对指定 Kana 的学习状态，若不存在则返回 null。
  Future<KanaLearningState?> getKanaLearningState(
    int userId,
    int kanaId,
  ) async {
    try {
      final results = await _db.query(
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

  /// 返回指定 Kana 的例词列表（来自 `kana_examples`）。
  Future<List<KanaExample>> _getKanaExamples(int kanaId) async {
    try {
      final results = await _db.query(
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
}
