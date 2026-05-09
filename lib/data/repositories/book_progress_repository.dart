import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/book_progress.dart';

/// 辞书学习进度聚合仓库（每用户每本书一条记录）
class BookProgressRepository {
  BookProgressRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  /// 获取进度记录（不存在则返回 null）
  Future<BookProgress?> getProgress(int userId, String bookId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'book_progress',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'book_progress',
        where: 'user_id=$userId AND book_id=$bookId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return BookProgress.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 插入新进度记录
  Future<int> createProgress(BookProgress progress) async {
    try {
      final db = await _db;
      final id = await db.insert('book_progress', progress.toMapForInsert());

      logger.dbInsert(
        table: 'book_progress',
        id: id,
        keyFields: {'bookId': progress.bookId, 'userId': progress.userId},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新进度记录（upsert 语义：存在则更新，不存在则插入）
  Future<void> upsertProgress(BookProgress progress) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.insert('book_progress', {
        ...progress.toMapForInsert(),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新排序游标（完成批次后推进）
  Future<void> updateCursor(int userId, String bookId, int newCursor) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.update(
        'book_progress',
        {'current_sort_cursor': newCursor, 'updated_at': now},
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除进度记录（重置时使用）
  Future<void> deleteProgress(int userId, String bookId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'book_progress',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );

      logger.dbDelete(table: 'book_progress', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取某个用户的全部书籍进度
  Future<List<BookProgress>> getAllByUser(int userId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'book_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return results.map(BookProgress.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT ALL',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除某个用户的全部书籍进度
  Future<void> deleteAllByUser(int userId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'book_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(table: 'book_progress', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
