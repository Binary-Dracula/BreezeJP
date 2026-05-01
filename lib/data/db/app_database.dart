import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';

class AppDatabase {
  static const _dbName = "breeze_jp.sqlite";
  static const _dbVersion = 4;

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
    final bookColumns = await db.rawQuery("PRAGMA table_info(books)");
    final hasIsAvailable = bookColumns.any(
      (row) => row['name'] == 'is_available',
    );

    if (!hasIsAvailable) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN is_available INTEGER NOT NULL DEFAULT 1',
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_available_sort ON books (is_available, sort_order)',
    );

    final sessionColumns = await db.rawQuery(
      "PRAGMA table_info(learning_sessions)",
    );
    final hasWordsPayload = sessionColumns.any(
      (row) => row['name'] == 'words_payload',
    );

    if (!hasWordsPayload && sessionColumns.isNotEmpty) {
      await db.execute(
        'ALTER TABLE learning_sessions ADD COLUMN words_payload TEXT',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        sync_user_id TEXT PRIMARY KEY,
        device_id TEXT,
        last_pulled_seq INTEGER NOT NULL DEFAULT 0,
        last_push_at INTEGER,
        last_success_at INTEGER,
        bootstrap_version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_user_id TEXT NOT NULL,
        mutation_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_key TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        base_version INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        last_error TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        UNIQUE(sync_user_id, mutation_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_user_status_created ON sync_outbox (sync_user_id, status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status_retry ON sync_outbox (status, next_retry_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_word_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, word_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_word_favorites_user_updated ON user_word_favorites (user_id, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_word_favorites_user_book ON user_word_favorites (user_id, book_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_word_example_favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        example_id TEXT NOT NULL,
        word_id TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        UNIQUE(user_id, example_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_word_example_favorites_user_updated ON user_word_example_favorites (user_id, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_word_example_favorites_user_word ON user_word_example_favorites (user_id, word_id)',
    );

    await _ensureKanaSchemaAndContent(db);
  }

  Future<void> _ensureKanaSchemaAndContent(Database db) async {
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
      CREATE TABLE IF NOT EXISTS kana_examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kana_id INTEGER,
        example_jp TEXT,
        example_furigana TEXT,
        example_cn TEXT,
        created_at TEXT,
        FOREIGN KEY(kana_id) REFERENCES kana_letters(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_stroke_order (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kana_id INTEGER NOT NULL UNIQUE REFERENCES kana_letters(id),
        svg TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kana_learning_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        kana_id INTEGER NOT NULL REFERENCES kana_letters(id),
        learning_status INTEGER DEFAULT 0 NOT NULL,
        next_review_at INTEGER,
        last_reviewed_at INTEGER,
        streak INTEGER DEFAULT 0,
        total_reviews INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        interval REAL DEFAULT 0,
        ease_factor REAL DEFAULT 2.5,
        stability REAL DEFAULT 0,
        difficulty REAL DEFAULT 0,
        created_at INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
        updated_at INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
        UNIQUE (user_id, kana_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kana_review_schedule ON kana_learning_state (user_id, learning_status, next_review_at)',
    );

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
      final kanaExampleRows = await seedDb.query('kana_examples');
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

        for (final row in kanaExampleRows) {
          batch.insert(
            'kana_examples',
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
        '[DB] kana_seed_complete: audio=${kanaAudioRows.length} letters=${kanaLetterRows.length} examples=${kanaExampleRows.length} stroke=${kanaStrokeRows.length}',
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
