import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/kana_audio.dart';
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
          .map((map) => KanaGroupItem(group: map['row_group'] as String))
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
          .map((map) => KanaTypeItem(type: map['kana_category'] as String))
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

  /// 加载指定 Kana 的完整详情，包括关联数据。
  ///
  /// 若 Kana 字符不存在则返回 null。
  Future<KanaDetail?> getKanaDetail(int kanaId) async {
    try {
      final letter = await getKanaLetterById(kanaId);
      if (letter == null) {
        logger.warning('Kana not found: $kanaId');
        return null;
      }

      final audio = await getKanaAudioByKanaId(kanaId);
      final strokeOrder = await getKanaStrokeOrder(kanaId);

      logger.debug('Kana detail loaded: ${letter.kanaChar}');

      return KanaDetail(letter: letter, audio: audio, strokeOrder: strokeOrder);
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

  /// 获取所有假名字母列表（用于生成干扰项）
  Future<List<KanaLetter>> getAllKanaLetters() async {
    try {
      final results = await _db.query('kana_letters');
      return results.map((map) => KanaLetter.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'kana_letters (all)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据 pair_group_id 查找指定假名的配对假名（平假名 ↔ 片假名）。
  ///
  /// 例如：给定平假名 あ，返回片假名 ア（相同 pair_group_id，不同 script_kind）。
  /// 若无 pair_group_id 或找不到对应配对，返回 null。
  Future<KanaLetter?> getKanaCounterpart(KanaLetter letter) async {
    if (letter.pairGroupId == null) return null;

    final oppositeKind = letter.scriptKind == KanaScriptKind.hiragana
        ? 'katakana'
        : 'hiragana';

    try {
      final results = await _db.query(
        'kana_letters',
        where: 'pair_group_id = ? AND script_kind = ?',
        whereArgs: [letter.pairGroupId, oppositeKind],
        limit: 1,
      );

      logger.dbQuery(
        table: 'kana_letters',
        where:
            'pair_group_id = ${letter.pairGroupId}, script_kind = $oppositeKind',
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
}
