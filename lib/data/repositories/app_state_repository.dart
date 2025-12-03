import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/app_state.dart';

/// 应用状态数据仓库
/// 管理 app_state 表中的当前活跃用户信息
class AppStateRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  /// 读取应用状态（仅一行）
  Future<AppState?> getAppState() async {
    try {
      final db = await _db;
      final results = await db.query('app_state', limit: 1);

      logger.dbQuery(
        table: 'app_state',
        where: 'singleton',
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

  /// 获取当前活跃用户 ID
  Future<int?> getCurrentUserId() async {
    final state = await getAppState();
    return state?.currentUserId;
  }

  /// 设置当前活跃用户 ID（如不存在则创建）
  Future<AppState> setCurrentUserId(int userId) async {
    try {
      final db = await _db;
      final id = await db.insert('app_state', {
        'id': AppState.singletonId,
        'current_user_id': userId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      logger.dbInsert(
        table: 'app_state',
        id: id,
        keyFields: {'current_user_id': userId},
      );

      return AppState(id: AppState.singletonId, currentUserId: userId);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'app_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 清空当前活跃用户
  Future<void> clearCurrentUser() async {
    try {
      final db = await _db;
      final affectedRows = await db.update(
        'app_state',
        {'current_user_id': null},
        where: 'id = ?',
        whereArgs: [AppState.singletonId],
      );

      logger.dbUpdate(
        table: 'app_state',
        affectedRows: affectedRows,
        updatedFields: ['current_user_id'],
      );
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
}
