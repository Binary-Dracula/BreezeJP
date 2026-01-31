import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/kana_audio.dart';
import '../models/kana_example.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_letter.dart';
import '../models/kana_stroke_order.dart';
import '../models/read/kana_detail.dart';
import '../models/read/kana_group_item.dart';
import '../models/read/kana_type_item.dart';

/// Kana 相关只读查询的辅助类。
///
/// 统一管理 `kana_*` 表的关联、过滤与聚合查询，并返回类型化模型对象。
/// 每个方法都会记录查询日志，发生数据库错误时会记录并重新抛出，便于调用方统一处理。
class KanaQuery {
  KanaQuery(this._db);

  final Database _db;

  /// 从 `kana_letters` 中返回去重后的分组名称，
  /// 并按每个分组内最早的 `display_order` 排序。
  Future<List<KanaGroupItem>> getAllKanaGroups() async {
    try {
      final results = await _db.rawQuery('''
        SELECT DISTINCT row_group
        FROM kana_letters
        WHERE row_group IS NOT NULL
        ORDER BY MIN(display_order)
      ''');

      logger.dbQuery(
        table: 'kana_letters',
        where: 'DISTINCT row_group',
        resultCount: results.length,
      );

      return results
          .map(
            (map) => KanaGroupItem(group: map['row_group'] as String),
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
  /// 并按每个类型内最早的 `display_order` 排序。
  Future<List<KanaTypeItem>> getAllKanaTypes() async {
    try {
      final results = await _db.rawQuery('''
        SELECT DISTINCT kana_category
        FROM kana_letters
        WHERE kana_category IS NOT NULL
        GROUP BY kana_category
        ORDER BY MIN(display_order)
      ''');

      logger.dbQuery(
        table: 'kana_letters',
        where: 'DISTINCT kana_category',
        resultCount: results.length,
      );

      return results
          .map(
            (map) => KanaTypeItem(type: map['kana_category'] as String),
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

  /// 返回用户当前处于 learning 状态的学习记录。
  Future<List<KanaLearningState>> getDueReviewKana(int userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final results = await _db.query(
        'kana_learning_state',
        where:
            'user_id = ? AND learning_status = ? '
            'AND (next_review_at IS NULL OR next_review_at <= ?)',
        whereArgs: [userId, LearningStatus.learning.value, now],
        orderBy: 'next_review_at ASC',
      );

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, learning kana, next_review_at <= $now',
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

  /// 统计用户处于 learning 状态的学习数量。
  Future<int> countDueKanaReviews(int userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt
        FROM kana_learning_state
        WHERE user_id = ?
          AND learning_status = ?
          AND (next_review_at IS NULL OR next_review_at <= ?)
      ''',
        [userId, LearningStatus.learning.value, now],
      );

      final count = (result.first['cnt'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, learning count, next_review_at <= $now',
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

  /// 统计用户处于 mastered 状态的学习数量。
  Future<int> countMasteredKana({required int userId}) async {
    try {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt
        FROM kana_learning_state
        WHERE user_id = ?
          AND learning_status = ?
      ''',
        [userId, LearningStatus.mastered.value],
      );

      final count = (result.first['cnt'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'user_id = $userId, mastered count',
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

  /// 统计全部 Kana 字符数量。
  Future<int> countTotalKana() async {
    try {
      final result = await _db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM kana_letters',
      );
      final count = (result.first['cnt'] as int?) ?? 0;

      logger.dbQuery(
        table: 'kana_letters',
        where: 'total count',
        resultCount: 1,
      );

      return count;
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

  /// 返回用户处于 learning 状态的 Kana 字符。
  ///
  /// 关联 `kana_letters` 与 `kana_learning_state`，
  /// 过滤条件为 `learning_status = learning`。
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
          AND (kls.next_review_at IS NULL OR kls.next_review_at <= ?)
        ORDER BY kls.next_review_at ASC, kl.display_order ASC
      ''',
        [userId, LearningStatus.learning.value, now],
      );

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'user_id = $userId, learning list, next_review_at <= $now',
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

      final audio = await getKanaAudioByKanaId(kanaId);
      final examples = await _getKanaExamples(kanaId);
      final learningState = await getKanaLearningState(userId, kanaId);
      final strokeOrder = await getKanaStrokeOrder(kanaId);

      logger.debug(
        'Kana detail loaded: ${letter.kanaChar} (${examples.length} examples)',
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
          kls.next_review_at as state_next_review_at,
          kls.last_reviewed_at as state_last_reviewed_at,
          kls.streak as state_streak,
          kls.total_reviews as state_total_reviews,
          kls.fail_count as state_fail_count,
          kls.interval as state_interval,
          kls.ease_factor as state_ease_factor,
          kls.stability as state_stability,
          kls.difficulty as state_difficulty,
          kls.created_at as state_created_at,
          kls.updated_at as state_updated_at
        FROM kana_letters kl
        LEFT JOIN kana_learning_state kls ON kl.id = kls.kana_id AND kls.user_id = ?
        ORDER BY kl.display_order ASC
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
            nextReviewAt: map['state_next_review_at'] as int?,
            lastReviewedAt: map['state_last_reviewed_at'] as int?,
            streak: map['state_streak'] as int? ?? 0,
            totalReviews: map['state_total_reviews'] as int? ?? 0,
            failCount: map['state_fail_count'] as int? ?? 0,
            interval: (map['state_interval'] as num?)?.toDouble() ?? 0,
            easeFactor:
                (map['state_ease_factor'] as num?)?.toDouble() ??
                AppConstants.defaultEaseFactor,
            stability: (map['state_stability'] as num?)?.toDouble() ?? 0,
            difficulty: (map['state_difficulty'] as num?)?.toDouble() ?? 0,
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

  /// 返回指定 Kana 的音频记录（如存在）。
  Future<KanaAudio?> getKanaAudioByKanaId(int kanaId) async {
    try {
      final results = await _db.rawQuery(
        '''
        SELECT ka.*
        FROM kana_letters kl
        LEFT JOIN kana_audio ka ON ka.id = kl.audio_id
        WHERE kl.id = ?
        LIMIT 1
      ''',
        [kanaId],
      );

      logger.dbQuery(
        table: 'kana_letters + kana_audio',
        where: 'kana_id = $kanaId',
        resultCount: results.length,
      );

      final row = results.isNotEmpty ? results.first : null;
      if (row == null || row['id'] == null) return null;
      return KanaAudio.fromMap(row);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters + kana_audio',
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
