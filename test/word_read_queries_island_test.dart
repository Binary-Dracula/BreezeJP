import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  const testUserId = 1;

  Future<void> createTestSchema(Database db) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY,
        word TEXT NOT NULL,
        furigana TEXT,
        romaji TEXT,
        jlpt_level TEXT,
        part_of_speech TEXT,
        pitch_accent TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE word_meanings (
        id INTEGER PRIMARY KEY,
        word_id INTEGER NOT NULL,
        meaning_cn TEXT NOT NULL,
        definition_order INTEGER DEFAULT 1,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE study_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        user_state INTEGER DEFAULT 0,
        next_review_at INTEGER,
        last_reviewed_at INTEGER,
        interval INTEGER DEFAULT 0,
        ease_factor REAL DEFAULT 2.5,
        stability REAL DEFAULT 0,
        difficulty REAL DEFAULT 0,
        streak INTEGER DEFAULT 0,
        total_reviews INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE word_relations (
        id INTEGER PRIMARY KEY,
        word_id INTEGER NOT NULL,
        related_word_id INTEGER NOT NULL,
        relation_type TEXT,
        score REAL DEFAULT 0
      )
    ''');
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await createTestSchema(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ======================================================
  // Helper: 执行与 getRandomUnmasteredWordsWithMeaning 相同的 SQL
  // ======================================================
  Future<List<Map<String, Object?>>> queryRandomUnmastered({
    required int userId,
    int count = 5,
  }) async {
    return db.rawQuery(
      '''
      SELECT w.id, w.word, w.jlpt_level
      FROM words w
      LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
      WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
      ORDER BY
        CASE w.jlpt_level
          WHEN 'N5' THEN 1
          WHEN 'N4' THEN 2
          WHEN 'N3' THEN 3
          WHEN 'N2' THEN 4
          WHEN 'N1' THEN 5
          ELSE 6
        END,
        RANDOM()
      LIMIT ?
    ''',
      [userId, count],
    );
  }

  // ======================================================
  // Helper: 执行与 getRandomUnmasteredSeedWord 相同的 SQL
  // ======================================================
  Future<Map<String, Object?>?> querySeedWord({
    required int userId,
    List<int> excludeIds = const [],
  }) async {
    final args = <Object>[userId];
    var excludeClause = '';
    if (excludeIds.isNotEmpty) {
      final placeholders = List.filled(excludeIds.length, '?').join(',');
      excludeClause = 'AND w.id NOT IN ($placeholders)';
      args.addAll(excludeIds);
    }

    final rows = await db.rawQuery('''
      SELECT w.*
      FROM words w
      LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
      WHERE (sw.user_state IS NULL OR sw.user_state IN (0, 1))
        $excludeClause
      ORDER BY
        CASE w.jlpt_level
          WHEN 'N5' THEN 1
          WHEN 'N4' THEN 2
          WHEN 'N3' THEN 3
          WHEN 'N2' THEN 4
          WHEN 'N1' THEN 5
          ELSE 6
        END,
        RANDOM()
      LIMIT 1
    ''', args);

    return rows.isEmpty ? null : rows.first;
  }

  // ======================================================
  // Helper: 执行与 getRelatedWords 相同的 SQL
  // ======================================================
  Future<List<Map<String, Object?>>> queryRelatedWords({
    required int userId,
    required int wordId,
  }) async {
    return db.rawQuery(
      '''
      SELECT w.*, wr.score, wr.relation_type
      FROM word_relations wr
      JOIN words w ON wr.related_word_id = w.id
      LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
      WHERE wr.word_id = ?
        AND (sw.user_state IS NULL OR sw.user_state IN (0, 1))
      ORDER BY wr.score DESC
    ''',
      [userId, wordId],
    );
  }

  // ======================================================
  // N5 优先排序
  // ======================================================
  group('N5 优先排序 - getRandomUnmasteredWordsWithMeaning', () {
    test('优先返回 N5 单词', () async {
      // 插入 6 个 N5 + 4 个其他等级
      for (int i = 1; i <= 6; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'n5_word_$i',
          'jlpt_level': 'N5',
        });
      }
      for (int i = 7; i <= 10; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'n4_word_$i',
          'jlpt_level': 'N4',
        });
      }

      final results = await queryRandomUnmastered(userId: testUserId, count: 5);

      expect(results.length, 5);
      for (final row in results) {
        expect(row['jlpt_level'], 'N5', reason: '有足够的 N5 单词时，应全部返回 N5');
      }
    });

    test('N5 不足时回退到 N4', () async {
      // 2 个 N5 + 5 个 N4
      await db.insert('words', {'id': 1, 'word': 'n5_a', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 2, 'word': 'n5_b', 'jlpt_level': 'N5'});
      for (int i = 3; i <= 7; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'n4_$i',
          'jlpt_level': 'N4',
        });
      }

      final results = await queryRandomUnmastered(userId: testUserId, count: 5);

      expect(results.length, 5);

      // 前 2 个应为 N5
      final n5Results = results.where((r) => r['jlpt_level'] == 'N5').toList();
      final n4Results = results.where((r) => r['jlpt_level'] == 'N4').toList();
      expect(n5Results.length, 2);
      expect(n4Results.length, 3);
    });

    test('已掌握的 N5 不出现', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 3 个 N5，其中 2 个已掌握
      await db.insert('words', {'id': 1, 'word': 'n5_a', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 2, 'word': 'n5_b', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 3, 'word': 'n5_c', 'jlpt_level': 'N5'});

      // word 1, 2 已掌握 (user_state = 2)
      await db.insert('study_words', {
        'user_id': testUserId,
        'word_id': 1,
        'user_state': 2,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('study_words', {
        'user_id': testUserId,
        'word_id': 2,
        'user_state': 2,
        'created_at': now,
        'updated_at': now,
      });

      // 3 个 N4 补充
      for (int i = 4; i <= 6; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'n4_$i',
          'jlpt_level': 'N4',
        });
      }

      final results = await queryRandomUnmastered(userId: testUserId, count: 5);

      expect(results.length, 4); // 1 个 N5 + 3 个 N4
      final ids = results.map((r) => r['id']).toSet();
      expect(ids.contains(1), false, reason: '已掌握的 word 1 不应出现');
      expect(ids.contains(2), false, reason: '已掌握的 word 2 不应出现');
      expect(ids.contains(3), true, reason: '未掌握的 word 3 应出现');
    });
  });

  // ======================================================
  // 种子词查询
  // ======================================================
  group('种子词查询 - getRandomUnmasteredSeedWord', () {
    test('排除已有 ID', () async {
      for (int i = 1; i <= 5; i++) {
        await db.insert('words', {
          'id': i,
          'word': 'word_$i',
          'jlpt_level': 'N5',
        });
      }

      final result = await querySeedWord(
        userId: testUserId,
        excludeIds: [1, 2, 3],
      );

      expect(result, isNotNull);
      final id = result!['id'] as int;
      expect([1, 2, 3].contains(id), false, reason: '种子词不应在 excludeIds 中');
      expect([4, 5].contains(id), true);
    });

    test('无可用词时返回 null', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db.insert('words', {'id': 1, 'word': 'w1', 'jlpt_level': 'N5'});
      await db.insert('study_words', {
        'user_id': testUserId,
        'word_id': 1,
        'user_state': 2,
        'created_at': now,
        'updated_at': now,
      });

      final result = await querySeedWord(userId: testUserId);
      expect(result, isNull);
    });

    test('种子词优先 N5', () async {
      await db.insert('words', {'id': 1, 'word': 'n3', 'jlpt_level': 'N3'});
      await db.insert('words', {'id': 2, 'word': 'n5', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 3, 'word': 'n4', 'jlpt_level': 'N4'});

      final result = await querySeedWord(userId: testUserId);

      expect(result, isNotNull);
      expect(result!['jlpt_level'], 'N5', reason: '优先返回 N5 单词');
    });
  });

  // ======================================================
  // 关联词查询
  // ======================================================
  group('关联词查询 - getRelatedWords', () {
    test('过滤已掌握', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 3 个单词
      await db.insert('words', {'id': 1, 'word': 'w1', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 2, 'word': 'w2', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 3, 'word': 'w3', 'jlpt_level': 'N5'});

      // word 1 关联 word 2 和 word 3
      await db.insert('word_relations', {
        'word_id': 1,
        'related_word_id': 2,
        'score': 0.8,
        'relation_type': 'synonym',
      });
      await db.insert('word_relations', {
        'word_id': 1,
        'related_word_id': 3,
        'score': 0.5,
        'relation_type': 'synonym',
      });

      // word 3 已掌握
      await db.insert('study_words', {
        'user_id': testUserId,
        'word_id': 3,
        'user_state': 2,
        'created_at': now,
        'updated_at': now,
      });

      final results = await queryRelatedWords(userId: testUserId, wordId: 1);

      expect(results.length, 1, reason: '已掌握的 word 3 不应出现');
      expect(results.first['id'], 2);
    });

    test('按 score DESC 排序', () async {
      await db.insert('words', {'id': 1, 'word': 'w1', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 2, 'word': 'w2', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 3, 'word': 'w3', 'jlpt_level': 'N5'});
      await db.insert('words', {'id': 4, 'word': 'w4', 'jlpt_level': 'N5'});

      await db.insert('word_relations', {
        'word_id': 1,
        'related_word_id': 2,
        'score': 0.3,
      });
      await db.insert('word_relations', {
        'word_id': 1,
        'related_word_id': 3,
        'score': 0.9,
      });
      await db.insert('word_relations', {
        'word_id': 1,
        'related_word_id': 4,
        'score': 0.6,
      });

      final results = await queryRelatedWords(userId: testUserId, wordId: 1);

      expect(results.length, 3);
      final scores = results.map((r) => r['score'] as double).toList();
      expect(scores, [0.9, 0.6, 0.3], reason: '应按 score 降序排列');
    });
  });
}
