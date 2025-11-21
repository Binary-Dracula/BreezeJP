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
      logger.database('INSERT', table: 'users', data: user.toMap());

      final db = await _db;
      final id = await db.insert('users', user.toMap());

      logger.info('创建用户成功: username=${user.username}');
      return id;
    } catch (e, stackTrace) {
      logger.error('创建用户失败', e, stackTrace);
      rethrow;
    }
  }

  /// 根据 ID 获取用户
  Future<User?> getUserById(int id) async {
    try {
      logger.database('SELECT', table: 'users', data: {'id': id});

      final db = await _db;
      final results = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取用户失败', e, stackTrace);
      rethrow;
    }
  }

  /// 根据用户名获取用户
  Future<User?> getUserByUsername(String username) async {
    try {
      logger.database('SELECT', table: 'users', data: {'username': username});

      final db = await _db;
      final results = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return User.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取用户失败', e, stackTrace);
      rethrow;
    }
  }

  /// 更新用户
  Future<void> updateUser(User user) async {
    try {
      logger.database('UPDATE', table: 'users', data: user.toMap());

      final db = await _db;
      await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      logger.info('更新用户成功: id=${user.id}');
    } catch (e, stackTrace) {
      logger.error('更新用户失败', e, stackTrace);
      rethrow;
    }
  }

  /// 删除用户
  Future<void> deleteUser(int id) async {
    try {
      logger.database('DELETE', table: 'users', data: {'id': id});

      final db = await _db;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);

      logger.info('删除用户成功: id=$id');
    } catch (e, stackTrace) {
      logger.error('删除用户失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取所有用户
  Future<List<User>> getAllUsers() async {
    try {
      logger.database('SELECT ALL', table: 'users');

      final db = await _db;
      final results = await db.query('users', orderBy: 'created_at DESC');

      return results.map((map) => User.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取所有用户失败', e, stackTrace);
      rethrow;
    }
  }
}
