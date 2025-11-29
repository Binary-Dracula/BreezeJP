import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/kana_letter.dart';
import '../models/kana_audio.dart';
import '../models/kana_example.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_quiz_record.dart';
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

  /// 获取假名的学习状态
  Future<KanaLearningState?> getKanaLearningState(int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_learning_state',
        where: 'kana_id = ?',
        whereArgs: [kanaId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_learning_state',
        where: 'kana_id = $kanaId',
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

  /// 获取所有假名的学习状态
  Future<List<KanaLearningState>> getAllKanaLearningStates() async {
    try {
      final db = await _db;
      final results = await db.query('kana_learning_state');

      logger.dbQuery(
        table: 'kana_learning_state',
        where: null,
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
      final map = state.toMap();
      map.remove('id'); // 移除 id，让数据库自动生成

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
  Future<void> markKanaAsLearned(int kanaId) async {
    try {
      final db = await _db;
      final now = DateTime.now().toIso8601String();

      // 检查是否已存在记录
      final existing = await getKanaLearningState(kanaId);

      if (existing != null) {
        await db.update(
          'kana_learning_state',
          {'is_learned': 1, 'last_review': now},
          where: 'kana_id = ?',
          whereArgs: [kanaId],
        );
        logger.dbUpdate(table: 'kana_learning_state', affectedRows: 1);
      } else {
        await db.insert('kana_learning_state', {
          'kana_id': kanaId,
          'is_learned': 1,
          'last_review': now,
          'easiness': 2.5,
          'interval': 0,
        });
        logger.dbInsert(table: 'kana_learning_state', id: kanaId);
      }

      logger.info('假名标记为已学习: kanaId=$kanaId');
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

  // ==================== 测验记录 ====================

  /// 获取假名的测验记录
  Future<List<KanaQuizRecord>> getKanaQuizRecords(int kanaId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'kana_quiz_records',
        where: 'kana_id = ?',
        whereArgs: [kanaId],
        orderBy: 'created_at DESC',
      );

      logger.dbQuery(
        table: 'kana_quiz_records',
        where: 'kana_id = $kanaId',
        resultCount: results.length,
      );

      return results.map((map) => KanaQuizRecord.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_quiz_records',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 添加测验记录
  Future<int> addKanaQuizRecord({
    required int kanaId,
    required bool correct,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now().toIso8601String();

      final result = await db.insert('kana_quiz_records', {
        'kana_id': kanaId,
        'correct': correct ? 1 : 0,
        'created_at': now,
      });

      logger.dbInsert(table: 'kana_quiz_records', id: result);

      return result;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'kana_quiz_records',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取假名的正确率
  Future<double> getKanaAccuracy(int kanaId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN correct = 1 THEN 1 ELSE 0 END) as correct_count
        FROM kana_quiz_records
        WHERE kana_id = ?
      ''',
        [kanaId],
      );

      logger.dbQuery(
        table: 'kana_quiz_records',
        where: 'kana_id = $kanaId (accuracy)',
        resultCount: 1,
      );

      final total = result.first['total'] as int;
      if (total == 0) return 0.0;

      final correctCount = result.first['correct_count'] as int;
      return correctCount / total;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_quiz_records',
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
  Future<KanaDetail?> getKanaDetail(int kanaId) async {
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
      final learningState = await getKanaLearningState(kanaId);

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
  Future<List<KanaLetterWithState>> getAllKanaLettersWithState() async {
    try {
      final db = await _db;
      final results = await db.rawQuery('''
        SELECT 
          kl.*,
          kls.id as state_id,
          kls.is_learned,
          kls.last_review,
          kls.next_review,
          kls.easiness,
          kls.interval
        FROM kana_letters kl
        LEFT JOIN kana_learning_state kls ON kl.id = kls.kana_id
        ORDER BY kl.sort_index ASC
      ''');

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: null,
        resultCount: results.length,
      );

      return results.map((map) {
        final letter = KanaLetter.fromMap(map);
        KanaLearningState? state;

        if (map['state_id'] != null) {
          state = KanaLearningState(
            id: map['state_id'] as int,
            kanaId: letter.id,
            isLearned: map['is_learned'] as int? ?? 0,
            lastReview: map['last_review'] as String?,
            nextReview: map['next_review'] as String?,
            easiness: (map['easiness'] as num?)?.toDouble() ?? 2.5,
            interval: map['interval'] as int? ?? 0,
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
  Future<Map<String, int>> getKanaLearningStats() async {
    try {
      final db = await _db;

      // 总假名数
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kana_letters',
      );
      final total = totalResult.first['count'] as int;

      // 已学习数
      final learnedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kana_learning_state WHERE is_learned = 1',
      );
      final learned = learnedResult.first['count'] as int;

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'stats',
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
  Future<List<KanaLetter>> getKanaDueForReview() async {
    try {
      final db = await _db;
      final now = DateTime.now().toIso8601String();

      final results = await db.rawQuery(
        '''
        SELECT kl.*
        FROM kana_letters kl
        INNER JOIN kana_learning_state kls ON kl.id = kls.kana_id
        WHERE kls.is_learned = 1
          AND (kls.next_review IS NULL OR kls.next_review <= ?)
        ORDER BY kls.next_review ASC
      ''',
        [now],
      );

      logger.dbQuery(
        table: 'kana_letters + kana_learning_state',
        where: 'due for review',
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
}
