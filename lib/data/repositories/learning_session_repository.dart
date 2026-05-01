import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../models/learning_session.dart';

/// 学习会话数据仓库（记录断点恢复状态）
class LearningSessionRepository {
  LearningSessionRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  /// 获取某本书的当前活跃会话（最多一条）
  Future<LearningSession?> getActiveSession(int userId, String bookId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'learning_sessions',
        where: 'user_id = ? AND book_id = ? AND status = ?',
        whereArgs: [userId, bookId, 'active'],
        limit: 1,
      );

      logger.dbQuery(
        table: 'learning_sessions',
        where: 'user_id=$userId AND book_id=$bookId AND status=active',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return LearningSession.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'learning_sessions',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 创建新会话
  Future<int> createSession(LearningSession session) async {
    try {
      final db = await _db;
      final id = await db.insert('learning_sessions', session.toMapForInsert());

      logger.dbInsert(
        table: 'learning_sessions',
        id: id,
        keyFields: {'bookId': session.bookId, 'userId': session.userId},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'learning_sessions',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新会话（currentIndex 推进或标记 completed）
  Future<void> updateSession(LearningSession session) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var deletedRows = 0;
      final affectedRows = await db.transaction((txn) async {
        if (session.status == 'completed') {
          deletedRows = await txn.delete(
            'learning_sessions',
            where: 'user_id = ? AND book_id = ? AND status = ? AND id != ?',
            whereArgs: [
              session.userId,
              session.bookId,
              'completed',
              session.id,
            ],
          );
        }

        return txn.update(
          'learning_sessions',
          {
            'current_index': session.currentIndex,
            'status': session.status,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [session.id],
        );
      });

      if (deletedRows > 0) {
        logger.dbDelete(table: 'learning_sessions', deletedRows: deletedRows);
      }

      logger.dbUpdate(
        table: 'learning_sessions',
        affectedRows: affectedRows,
        updatedFields: const ['current_index', 'status', 'updated_at'],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'learning_sessions',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除某本书的所有会话（重置时使用）
  Future<void> deleteAllByBook(int userId, String bookId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'learning_sessions',
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );

      logger.dbDelete(table: 'learning_sessions', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'learning_sessions',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
