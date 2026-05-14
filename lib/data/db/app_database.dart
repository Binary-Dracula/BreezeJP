import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';

class AppDatabase {
  static const _dbName = "breeze_jp.sqlite";
  static const _dbVersion = 5;

  static Database? _database;

  /// 外部调用入口： `final db = await AppDatabase.instance.database`
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Database get databaseSync {
    final db = _database;
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return db;
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

    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onOpen: (db) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureSchema(db);
      },
    );
    logger.info('[DB] init_complete: database opened successfully');
    return db;
  }

  Future<void> _ensureSchema(Database db) async {
    await _ensureLearningSessionSchema(db);

    await db.execute('DROP TABLE IF EXISTS study_words');
    await db.execute('DROP TABLE IF EXISTS book_progress');
    await db.execute('DROP TABLE IF EXISTS study_grammars');
    await db.execute('DROP TABLE IF EXISTS user_word_favorites');
    await db.execute('DROP TABLE IF EXISTS user_word_example_favorites');
    await db.execute('DROP TABLE IF EXISTS lesson_word_map');
    await db.execute('DROP TABLE IF EXISTS lessons');
    await db.execute('DROP TABLE IF EXISTS word_examples');
    await db.execute('DROP TABLE IF EXISTS word_details');
    await db.execute('DROP TABLE IF EXISTS words');
    await db.execute('DROP TABLE IF EXISTS books');
    await db.execute('DROP TABLE IF EXISTS grammar_examples');
    await db.execute('DROP TABLE IF EXISTS grammar_contexts');
    await db.execute('DROP TABLE IF EXISTS grammar_meanings');
    await db.execute('DROP TABLE IF EXISTS grammars');
    await db.execute('DROP TABLE IF EXISTS article_details');
    await db.execute('DROP TABLE IF EXISTS articles');

    await _ensureKanaSchemaAndContent(db);
  }

  Future<void> _ensureLearningSessionSchema(Database db) async {
    final sessionColumns = await db.rawQuery(
      'PRAGMA table_info(learning_sessions)',
    );
    final columnNames = sessionColumns
        .map((row) => row['name'] as String)
        .toSet();
    const targetColumns = {
      'id',
      'user_id',
      'session_type',
      'server_session_id',
      'book_id',
      'status',
      'data_payload',
      'created_at',
    };

    final needsRebuild =
        sessionColumns.isEmpty ||
        !columnNames.containsAll(targetColumns) ||
        columnNames.contains('words_payload') ||
        columnNames.contains('current_index') ||
        columnNames.contains('batch_start_sort') ||
        columnNames.contains('batch_end_sort') ||
        columnNames.contains('started_at') ||
        columnNames.contains('updated_at');

    if (needsRebuild) {
      await db.execute('DROP TABLE IF EXISTS learning_sessions');
      await db.execute('''
        CREATE TABLE learning_sessions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          session_type TEXT NOT NULL CHECK (
            session_type IN ('word_learn', 'word_review', 'kana_review')
          ),
          server_session_id TEXT,
          book_id TEXT,
          status TEXT NOT NULL CHECK (status IN ('active', 'completed')),
          data_payload TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    }

    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_sessions_active_book ON learning_sessions (user_id, book_id) WHERE session_type = 'word_learn' AND status = 'active'",
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_sessions_active_type ON learning_sessions (user_id, session_type) WHERE session_type != 'word_learn' AND status = 'active'",
    );
  }

  Future<void> _ensureKanaSchemaAndContent(Database db) async {
    await db.execute('DROP TABLE IF EXISTS kana_examples');
    await db.execute('DROP TABLE IF EXISTS kana_learning_state');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_audio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audio_filename TEXT NOT NULL,
        audio_source TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_letters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kana_char TEXT NOT NULL,
        script_kind TEXT NOT NULL,
        romaji TEXT NOT NULL,
        consonant TEXT,
        vowel TEXT NOT NULL,
        row_group TEXT,
        kana_category TEXT,
        display_order INTEGER,
        pair_group_id INTEGER,
        audio_id INTEGER REFERENCES kana_audio(id),
        mnemonic TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_stroke_order (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kana_id INTEGER NOT NULL UNIQUE REFERENCES kana_letters(id),
        svg TEXT
      )
    ''');

    final kanaAudioCount = await _countRows(db, 'kana_audio');
    final kanaLettersCount = await _countRows(db, 'kana_letters');
    final kanaStrokeOrderCount = await _countRows(db, 'kana_stroke_order');

    if (kanaAudioCount > 0 &&
        kanaLettersCount > 0 &&
        kanaStrokeOrderCount > 0) {
      return;
    }

    logger.info(
      '[DB] kana_seed_required: audio=$kanaAudioCount letters=$kanaLettersCount stroke=$kanaStrokeOrderCount',
    );
    await _upsertKanaContentFromAssets(db);
  }

  Future<int> _countRows(Database db, String table) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS cnt FROM $table');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> _upsertKanaContentFromAssets(Database db) async {
    final tempDir = await getTemporaryDirectory();
    final seedDbPath = join(tempDir.path, 'breeze_jp_kana_seed.sqlite');
    Database? seedDb;

    try {
      final assetData = await rootBundle.load('assets/database/$_dbName');
      await File(
        seedDbPath,
      ).writeAsBytes(assetData.buffer.asUint8List(), flush: true);

      seedDb = await openDatabase(seedDbPath, readOnly: true);

      final kanaAudioRows = await seedDb.query('kana_audio');
      final kanaLetterRows = await seedDb.query('kana_letters');
      final kanaStrokeRows = await seedDb.query('kana_stroke_order');

      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final row in kanaAudioRows) {
          batch.insert(
            'kana_audio',
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final row in kanaLetterRows) {
          batch.insert(
            'kana_letters',
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final row in kanaStrokeRows) {
          batch.insert(
            'kana_stroke_order',
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });

      logger.info(
        '[DB] kana_seed_complete: audio=${kanaAudioRows.length} letters=${kanaLetterRows.length} stroke=${kanaStrokeRows.length}',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'kana_*',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (seedDb != null) {
        await seedDb.close();
      }

      final seedFile = File(seedDbPath);
      if (await seedFile.exists()) {
        await seedFile.delete();
      }
    }
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
