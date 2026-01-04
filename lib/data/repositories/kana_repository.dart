import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/kana_letter.dart';
import '../models/kana_audio.dart';
import '../models/kana_example.dart';
import '../models/kana_learning_state.dart';
import '../models/kana_stroke_order.dart';

/// 五十音数据仓库
/// 负责所有与五十音图相关的数据库操作
class KanaRepository {
  KanaRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  /// 获取数据库实例
  Future<Database> get _db async => await _dbProvider();

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

  /// 创建假名学习状态
  Future<int> insertKanaLearningState(KanaLearningState state) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final map = state.toInsertMap();
      map['updated_at'] = now;

      final result = await db.insert('kana_learning_state', map);

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

  /// 删除用户的假名学习状态
  Future<int> deleteKanaLearningStatesByUser(int userId) async {
    try {
      final db = await _db;
      final count = await db.delete(
        'kana_learning_state',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(table: 'kana_learning_state', deletedRows: count);
      return count;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'kana_learning_state',
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

}
