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
      CREATE TABLE word_audio (
        id INTEGER PRIMARY KEY,
        word_id INTEGER NOT NULL,
        audio_filename TEXT,
        audio_url TEXT,
        voice_type TEXT,
        source TEXT
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
  }

  Future<void> insertTestData(Database db) async {
    // Insert words
    final words = [
      {
        'id': 1,
        'word': '食べる',
        'furigana': 'たべる',
        'jlpt_level': 'N5',
        'part_of_speech': '動詞',
      },
      {
        'id': 2,
        'word': '飲む',
        'furigana': 'のむ',
        'jlpt_level': 'N5',
        'part_of_speech': '動詞',
      },
      {
        'id': 3,
        'word': '走る',
        'furigana': 'はしる',
        'jlpt_level': 'N4',
        'part_of_speech': '動詞',
      },
      {
        'id': 4,
        'word': '大きい',
        'furigana': 'おおきい',
        'jlpt_level': 'N5',
        'part_of_speech': '形容詞',
      },
      {
        'id': 5,
        'word': '小さい',
        'furigana': 'ちいさい',
        'jlpt_level': 'N5',
        'part_of_speech': '形容詞',
      },
    ];
    for (final w in words) {
      await db.insert('words', w);
    }

    // Insert meanings
    final meanings = [
      {'word_id': 1, 'meaning_cn': '吃，食用', 'definition_order': 1},
      {'word_id': 2, 'meaning_cn': '喝，饮用', 'definition_order': 1},
      {'word_id': 3, 'meaning_cn': '跑，奔跑', 'definition_order': 1},
      {'word_id': 4, 'meaning_cn': '大的', 'definition_order': 1},
      {'word_id': 5, 'meaning_cn': '小的', 'definition_order': 1},
    ];
    for (final m in meanings) {
      await db.insert('word_meanings', m);
    }

    // Insert audio for some words
    await db.insert('word_audio', {
      'word_id': 1,
      'audio_filename': 'taberu.mp3',
      'audio_url': 'https://example.com/taberu.mp3',
    });
    await db.insert('word_audio', {
      'word_id': 2,
      'audio_filename': 'nomu.mp3',
      'audio_url': null,
    });

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Insert study_words: 3 learning, 2 mastered
    final studyWords = [
      {
        'user_id': testUserId,
        'word_id': 1,
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 100,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 2,
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 200,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 3,
        'user_state': LearningStatus.learning.value,
        'updated_at': now - 300,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 4,
        'user_state': LearningStatus.mastered.value,
        'updated_at': now - 50,
        'created_at': now - 1000,
      },
      {
        'user_id': testUserId,
        'word_id': 5,
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

      // 最近更新的应该排在前面
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

      // 不应有重复
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
      expect(items.first.furigana, 'のむ');
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
      expect(taberu.audioFilename, 'taberu.mp3');
      expect(taberu.audioUrl, 'https://example.com/taberu.mp3');

      final nomu = items.firstWhere((i) => i.word == '飲む');
      expect(nomu.audioFilename, 'nomu.mp3');
      expect(nomu.audioUrl, isNull);
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
      // Insert data for another user
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.insert('study_words', {
        'user_id': 999,
        'word_id': 1,
        'user_state': LearningStatus.learning.value,
        'updated_at': now,
        'created_at': now,
      });

      final items = await query.getVocabularyBookItems(
        userId: testUserId,
        status: LearningStatus.learning,
      );

      expect(items.length, 3); // 仍然是 3，不包含用户 999 的数据
    });
  });
}
