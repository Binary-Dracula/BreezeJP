import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/vocab_book.dart';

class BookRepository {
  BookRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  Future<void> upsertBooks(List<VocabBook> books) async {
    if (books.isEmpty) return;

    try {
      final db = await _db;
      final batch = db.batch();
      for (final book in books) {
        batch.insert(
          'books',
          book.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      logger.dbQuery(
        table: 'books',
        where: 'batch upsert ${books.length} rows',
        resultCount: books.length,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'BATCH UPSERT',
        table: 'books',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<VocabBook>> getAvailableBooks() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'books',
        where: 'is_available = 1',
        orderBy: 'sort_order ASC',
      );
      return rows.map(VocabBook.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'books',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<VocabBook?> getBookById(String id) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return VocabBook.fromMap(rows.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'books',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
