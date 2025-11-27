import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/user.dart';

/// 用户数据仓库
/// 负责所有与用户相关的数据库操作
class UserRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 基础 CRUD ====================

  /// 创建用户
  Future<int> createUser(User user) async {
    try {
      final db = await _db;
      final id = await db.insert('users', user.toMap());

      logger.dbInsert(
        table: 'users',
        id: id,
        keyFields: {'username': user.username},
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据 ID 获取用户
  Future<User?> getUserById(int id) async {
    try {
      final db = await _db;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      logger.dbQuery(
        table: 'users',
        where: 'id = $id',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 根据用户名获取用户
  Future<User?> getUserByUsername(String username) async {
    try {
      final db = await _db;
      final results = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      logger.dbQuery(
        table: 'users',
        where: 'username = $username',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 更新用户
  Future<void> updateUser(User user) async {
    try {
      final db = await _db;
      final affectedRows = await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      logger.dbUpdate(
        table: 'users',
        affectedRows: affectedRows,
        updatedFields: ['username', 'nickname', 'email', 'avatar_url'],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 删除用户
  Future<void> deleteUser(int id) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.dbDelete(table: 'users', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取所有用户
  Future<List<User>> getAllUsers() async {
    try {
      final db = await _db;
      final results = await db.query('users', orderBy: 'created_at DESC');

      logger.dbQuery(table: 'users', where: null, resultCount: results.length);

      return results.map((map) => User.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'users',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
