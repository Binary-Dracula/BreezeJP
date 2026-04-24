import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../queries/vocab_remote_query.dart';

/// 新词引入命令：一次事务内写入词条内容（words / word_details / word_examples / lesson_word_map）
///
/// 2.0 变更：不再创建 study_words 记录。学习状态由 LearnController 翻到时写入。
class WordIntroductionCommand {
  WordIntroductionCommand(this._db);

  final Database _db;

  Future<void> introduceFetchedWords({
    required String bookId,
    required List<WordDetailWithSort> words,
  }) async {
    if (words.isEmpty) return;

    await _db.transaction((txn) async {
      for (final wordWithSort in words) {
        final detail = wordWithSort.detail;
        final word = detail.word;

        await txn.insert(
          'words',
          word.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert('word_details', {
          'word_id': word.id,
          'rich_content': detail.richContent.toJsonString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await txn.delete(
          'word_examples',
          where: 'word_id = ?',
          whereArgs: [word.id],
        );
        for (final example in detail.examples) {
          await txn.insert('word_examples', example.toMap());
        }

        await txn.insert('lesson_word_map', {
          'id': '${bookId}_${word.id}',
          'book_id': bookId,
          'word_id': word.id,
          'sort_order': 0,
          'book_sort_order': wordWithSort.bookSortOrder,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    logger.info(
      '[WordIntroduction] introduceFetchedWords: bookId=$bookId count=${words.length}',
    );
  }
}
