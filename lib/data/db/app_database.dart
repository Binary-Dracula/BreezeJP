import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';

class AppDatabase {
  static const _dbName = "breeze_jp.sqlite";

  static Database? _database;

  /// 外部调用入口： `final db = await AppDatabase.instance.database`
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库：如果不存在则从 assets 复制
  Future<Database> _initDatabase() async {
    logger.info('[DB] init_start: initializing database');

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, _dbName);

    // 数据库不存在时，执行复制
    if (!await File(dbPath).exists()) {
      logger.info('[DB] copy_required: database not found at $dbPath');
      await _copyDatabaseFromAssets(dbPath);
    } else {
      logger.info('[DB] database_exists: path=$dbPath');
    }

    final db = await openDatabase(dbPath);
    logger.info('[DB] init_complete: database opened successfully');
    return db;
  }

  /// 将 assets/database/breeze_jp.sqlite 复制到应用目录
  Future<void> _copyDatabaseFromAssets(String targetPath) async {
    try {
      logger.info('[DB] copy_start: copying from assets/database/$_dbName');

      // 读取 assets 中的数据库文件
      final data = await rootBundle.load("assets/database/$_dbName");
      final bytes = data.buffer.asUint8List();

      // 写入本地
      await File(targetPath).writeAsBytes(bytes, flush: true);

      logger.info(
        '[DB] copy_complete: database copied to $targetPath, size=${bytes.length} bytes',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'COPY',
        table: 'database',
        dbError: e,
        stackTrace: stackTrace,
      );
      // 复制数据库失败，重新抛出异常
      rethrow;
    }
  }

  /// 可选：关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      logger.info('[DB] close: database connection closed');
    }
  }
}
