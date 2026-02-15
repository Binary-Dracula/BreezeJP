import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/word_audio.dart';

/// 单词音频仓库
/// 负责 word_audio 表的查询
class WordAudioRepository {
  WordAudioRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  /// 获取数据库实例
  Future<Database> get _db async => await _dbProvider();

  /// 获取单词的所有音频
  Future<List<WordAudio>> getWordAudios(int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'word_audio',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      logger.dbQuery(
        table: 'word_audio',
        where: 'word_id = $wordId',
        resultCount: results.length,
      );

      return results.map((map) => WordAudio.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'word_audio',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取单词的主要音频（第一个）
  Future<WordAudio?> getPrimaryWordAudio(int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'word_audio',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'word_audio',
        where: 'word_id = $wordId (primary)',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return WordAudio.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'word_audio',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
