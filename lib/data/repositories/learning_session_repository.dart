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
    return getActiveSessionByType(
      userId,
      LearningSessionType.wordLearn,
      bookId: bookId,
    );
  }

  Future<LearningSession?> getActiveSessionByType(
    int userId,
    LearningSessionType sessionType, {
    String? bookId,
  }) async {
    try {
      final db = await _db;
      final whereBuffer = StringBuffer('user_id = ? AND session_type = ?');
      final whereArgs = <Object?>[userId.toString(), sessionType.dbValue];

      if (bookId != null) {
        whereBuffer.write(' AND book_id = ?');
        whereArgs.add(bookId);
      }

      whereBuffer.write(' AND status = ?');
      whereArgs.add('active');

      final results = await db.query(
        'learning_sessions',
        where: whereBuffer.toString(),
        whereArgs: whereArgs,
        limit: 1,
      );

      logger.dbQuery(
        table: 'learning_sessions',
        where:
            'user_id=$userId AND session_type=${sessionType.dbValue} AND book_id=$bookId AND status=active',
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
  Future<String> createSession(LearningSession session) async {
    try {
      final db = await _db;
      await db.insert('learning_sessions', session.toMapForInsert());

      logger.dbInsert(
        table: 'learning_sessions',
        id: session.id,
        keyFields: {
          'bookId': session.bookId,
          'userId': session.userId,
          'sessionType': session.sessionType.dbValue,
        },
      );
      return session.id;
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
      final affectedRows = await db.update(
        'learning_sessions',
        session.toMapForUpdate(),
        where: 'id = ?',
        whereArgs: [session.id],
      );

      logger.dbUpdate(
        table: 'learning_sessions',
        affectedRows: affectedRows,
        updatedFields: const [
          'session_type',
          'server_session_id',
          'book_id',
          'status',
          'data_payload',
          'created_at',
        ],
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
        where: 'user_id = ? AND session_type = ? AND book_id = ?',
        whereArgs: [
          userId.toString(),
          LearningSessionType.wordLearn.dbValue,
          bookId,
        ],
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

  Future<void> deleteSession(String sessionId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'learning_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
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
