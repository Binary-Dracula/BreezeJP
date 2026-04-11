import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/word_detail.dart';
import '../queries/vocab_remote_query.dart';

/// 词汇内容写入仓库（2.0 — 管理 words / word_details / word_examples 三表）
class WordContentRepository {
  WordContentRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  /// 整词替换（upsert words + word_details + word_examples）
  ///
  /// 在一个事务中替换整个词条的所有数据。
  Future<void> upsertWordDetail(WordDetail detail) async {
    final db = await _db;
    await db.transaction((txn) async {
      final word = detail.word;

      // 1. Upsert words
      await txn.insert(
        'words',
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Upsert word_details
      await txn.insert('word_details', {
        'word_id': word.id,
        'rich_content': detail.richContent.toJsonString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 3. Replace word_examples (delete + insert)
      await txn.delete(
        'word_examples',
        where: 'word_id = ?',
        whereArgs: [word.id],
      );
      for (final example in detail.examples) {
        await txn.insert('word_examples', example.toMap());
      }
    });

    logger.dbInsert(
      table: 'words (upsert)',
      id: 0,
      keyFields: {'word_id': detail.word.id, 'word': detail.word.word},
    );
  }

  /// 批量整词替换
  Future<void> upsertWordDetails(List<WordDetail> details) async {
    for (final detail in details) {
      await upsertWordDetail(detail);
    }
  }

  /// 获取本地词汇数量（用于判断是否首装）
  Future<int> getLocalWordCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 读取 sync_metadata watermark
  Future<String?> getWatermark(String key) async {
    final db = await _db;
    final rows = await db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// 写入 sync_metadata watermark
  Future<void> setWatermark(String key, String value) async {
    final db = await _db;
    await db.insert('sync_metadata', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 保存从 API 拉取的书-词映射（upsert words/details/examples + lesson_word_map）
  Future<void> saveBookWordMappings(
    String bookId,
    List<WordDetailWithSort> words,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final wordWithSort in words) {
        final detail = wordWithSort.detail;
        final word = detail.word;

        // 1. Upsert words
        await txn.insert(
          'words',
          word.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Upsert word_details
        await txn.insert('word_details', {
          'word_id': word.id,
          'rich_content': detail.richContent.toJsonString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // 3. Replace word_examples (delete + insert)
        await txn.delete(
          'word_examples',
          where: 'word_id = ?',
          whereArgs: [word.id],
        );
        for (final example in detail.examples) {
          await txn.insert('word_examples', example.toMap());
        }

        // 4. Insert lesson_word_map (deterministic id, skip if exists)
        final mappingId = '${bookId}_${word.id}';
        await txn.insert('lesson_word_map', {
          'id': mappingId,
          'book_id': bookId,
          'word_id': word.id,
          'sort_order': 0,
          'book_sort_order': wordWithSort.bookSortOrder,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    logger.info(
      '[Repo] saveBookWordMappings: bookId=$bookId, count=${words.length}',
    );
  }
}
