import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/app_state.dart';

/// 应用状态数据仓库
/// 仅负责 app_state 表的基础 CRUD
class AppStateRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 读取指定 ID 的状态
  Future<AppState?> getState(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'app_state',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'app_state',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return AppState.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'app_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 创建状态记录
  Future<int> insertState(AppState state) async {
    try {
      final db = await _db;
      final id = await db.insert('app_state', state.toMap());

      logger.dbInsert(
        table: 'app_state',
        id: id,
        keyFields: {'id': state.id},
      );

      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'app_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新状态记录
  Future<int> updateState(AppState state) async {
    try {
      final db = await _db;
      final affectedRows = await db.update(
        'app_state',
        state.toMap(),
        where: 'id = ?',
        whereArgs: [state.id],
      );

      logger.dbUpdate(
        table: 'app_state',
        affectedRows: affectedRows,
        updatedFields: ['current_user_id'],
      );

      return affectedRows;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'app_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除状态记录
  Future<int> deleteState(int id) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'app_state',
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.dbDelete(table: 'app_state', deletedRows: deletedRows);
      return deletedRows;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'app_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
