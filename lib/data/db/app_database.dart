import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, _dbName);

    // 数据库不存在时，执行复制
    if (!await File(dbPath).exists()) {
      await _copyDatabaseFromAssets(dbPath);
    }

    return await openDatabase(dbPath);
  }

  /// 将 assets/database/breeze_jp.sqlite 复制到应用目录
  Future<void> _copyDatabaseFromAssets(String targetPath) async {
    try {
      // 读取 assets 中的数据库文件
      final data = await rootBundle.load("assets/database/$_dbName");
      final bytes = data.buffer.asUint8List();

      // 写入本地
      await File(targetPath).writeAsBytes(bytes, flush: true);

      // 数据库复制成功
    } catch (e) {
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
    }
  }
}
