import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/queries/vocabulary_book_query.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late VocabularyBookQuery query;

  const testUserId = 1;

  Future<void> createTestSchema(Database db) async {
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        reading TEXT,
        romaji TEXT,
        jlpt_level TEXT,
        part_of_speech TEXT,
        primary_meaning TEXT,
        has_audio INTEGER DEFAULT 0,
        transitivity TEXT,
        pitch_accent TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE study_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        word_id TEXT NOT NULL,
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
        first_learned_at INTEGER,
        introduced_at INTEGER,
        source_book_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, word_id)
      )
    ''');
  }

  Future<void> insertTestData(Database db) async {
    final words = [
      {
        'id': 'uuid-1',
        'word': '食べる',
        'reading': 'たべる',
        'romaji': 'taberu',
        'jlpt_level': 'N5',
        'part_of_speech': '動詞',
        'primary_meaning': '吃，食用',
        'has_audio': 1,
      },
      {
        'id': 'uuid-2',
        'word': '飲む',
        'reading': 'のむ',
        'romaji': 'nomu',
        'jlpt_level': 'N5',
        'part_of_speech': '動詞',
        'primary_meaning': '喝，饮用',
        'has_audio': 1,
      },
      {
        'id': 'uuid-3',
        'word': '走る',
        'reading': 'はしる',
        'romaji': 'hashiru',
        'jlpt_level': 'N4',
        'part_of_speech': '動詞',
        'primary_meaning': '跑，奔跑',
        'has_audio': 0,
      },
      {
        'id': 'uuid-4',
        'word': '大きい',
        'reading': 'おおきい',
        'romaji': 'ookii',
        'jlpt_level': 'N5',
        'part_of_speech': '形容詞',
        'primary_meaning': '大的',
        'has_audio': 0,
      },
      {
        'id': 'uuid-5',
        'word': '小さい',
        'reading': 'ちいさい',
        'romaji': 'chiisai',
        'jlpt_level': 'N5',
        'part_of_speech': '形容詞',
        'primary_meaning': '小的',
        'has_audio': 0,
      },
    ];
    for (final w in words) {
      await db.insert('words', w);
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final studyWords = [
      {
        'user_id': testUserId,
        'word_id': 'uuid-1',
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 100,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 'uuid-2',
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 200,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 'uuid-3',
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 300,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 'uuid-4',
        'user_state': LearningStatus.mastered.value,
        'updated_at': now - 50,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 'uuid-5',
        'user_state': LearningStatus.mastered.value,
        'updated_at': now - 150,
        'created_at': now - 1000,
      },
    ];
    for (final sw in studyWords) {
      await db.insert('study_words', sw);
    }
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await createTestSchema(db);
    await insertTestData(db);
    query = VocabularyBookQuery(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('VocabularyBookQuery', () {
    test('按 learning 状态查询返回正确数据', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      expect(items.length, 3);
      expect(items.every((i) => i.userState == LearningStatus.learning), true);
    });

    test('按 mastered 状态查询返回正确数据', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.mastered,
      );

      expect(items.length, 2);
      expect(items.every((i) => i.userState == LearningStatus.mastered), true);
    });

    test('按 updated_at DESC 排序', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      for (int i = 0; i < items.length - 1; i++) {
        expect(
          items[i].updatedAt.isAfter(items[i + 1].updatedAt) ||
              items[i].updatedAt.isAtSameMomentAs(items[i + 1].updatedAt),
          true,
          reason:
              '${items[i].word} (${items[i].updatedAt}) 应在 ${items[i + 1].word} (${items[i + 1].updatedAt}) 之前',
        );
      }
    });

    test('分页 limit/offset', () async {
      final page1 = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        limit: 2,
        offset: 0,
      );
      expect(page1.length, 2);

      final page2 = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        limit: 2,
        offset: 2,
      );
      expect(page2.length, 1);

      final page1Ids = page1.map((i) => i.wordId).toSet();
      final page2Ids = page2.map((i) => i.wordId).toSet();
      expect(page1Ids.intersection(page2Ids), isEmpty);
    });

    test('搜索过滤 - 按单词', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        searchQuery: '食べる',
      );

      expect(items.length, 1);
      expect(items.first.word, '食べる');
    });

    test('搜索过滤 - 按假名', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        searchQuery: 'のむ',
      );

      expect(items.length, 1);
      expect(items.first.reading, 'のむ');
    });

    test('搜索过滤 - 按罗马音', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        searchQuery: 'taberu',
      );

      expect(items.length, 1);
      expect(items.first.word, '食べる');
    });

    test('搜索过滤 - 按释义', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        searchQuery: '吃',
      );

      expect(items.length, 1);
      expect(items.first.primaryMeaning, '吃，食用');
    });

    test('搜索无结果时返回空列表', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
        searchQuery: '不存在的单词',
      );

      expect(items, isEmpty);
    });

    test('包含音频信息', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      final taberu = items.firstWhere((i) => i.word == '食べる');
      expect(taberu.hasAudio, true);

      final hashiru = items.firstWhere((i) => i.word == '走る');
      expect(hashiru.hasAudio, false);
    });

    test('包含 JLPT 和词性', () async {
      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      final taberu = items.firstWhere((i) => i.word == '食べる');
      expect(taberu.jlptLevel, 'N5');
      expect(taberu.partOfSpeech, '動詞');
    });

    test('getStatusCounts 返回正确的数量', () async {
      final counts = await query.getStatusCounts(userId: testUserId);

      expect(counts[LearningStatus.learning], 3);
      expect(counts[LearningStatus.mastered], 2);
    });

    test('getStatusCounts 带搜索过滤', () async {
      final counts = await query.getStatusCounts(
        userId: testUserId,
        searchQuery: '食べる',
      );

      expect(counts[LearningStatus.learning], 1);
      expect(counts[LearningStatus.mastered], 0);
    });

    test('不返回其他用户的数据', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.insert('study_words', {
        'user_id': 999,
        'word_id': 'uuid-1',
        'user_state': LearningStatus.learning.value,
        'updated_at': now,
        'created_at': now,
      });

      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      expect(items.length, 3);
    });
  });
}
