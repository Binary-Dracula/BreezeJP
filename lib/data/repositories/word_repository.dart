import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/word.dart';
import '../models/word_meaning.dart';
import '../models/word_audio.dart';
import '../models/example_sentence.dart';
import '../models/example_audio.dart';
import '../models/word_detail.dart';

/// 单词数据仓库
/// 负责所有与单词相关的数据库操作
class WordRepository {
  /// 获取数据库实例
  Future<Database> get _db async => await AppDatabase.instance.database;

  // ==================== 单词查询 ====================

  /// 根据 ID 获取单词
  Future<Word?> getWordById(int id) async {
    try {
      logger.database('SELECT', table: 'words', data: {'id': id});

      final db = await _db;
      final results = await db.query(
        'words',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return Word.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取单词失败', e, stackTrace);
      rethrow;
    }
  }

  /// 根据 JLPT 等级获取单词列表
  Future<List<Word>> getWordsByLevel(String jlptLevel) async {
    try {
      logger.database(
        'SELECT',
        table: 'words',
        data: {'jlpt_level': jlptLevel},
      );

      final db = await _db;
      final results = await db.query(
        'words',
        where: 'jlpt_level = ?',
        whereArgs: [jlptLevel],
        orderBy: 'id ASC',
      );

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取单词列表失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取所有单词
  Future<List<Word>> getAllWords({int? limit, int? offset}) async {
    try {
      logger.database('SELECT', table: 'words');

      final db = await _db;
      final results = await db.query(
        'words',
        orderBy: 'id ASC',
        limit: limit,
        offset: offset,
      );

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取所有单词失败', e, stackTrace);
      rethrow;
    }
  }

  /// 搜索单词（按单词文本、假名或罗马音）
  Future<List<Word>> searchWords(String keyword) async {
    try {
      logger.database('SELECT', table: 'words', data: {'keyword': keyword});

      final db = await _db;
      final results = await db.query(
        'words',
        where: 'word LIKE ? OR furigana LIKE ? OR romaji LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
        orderBy: 'id ASC',
      );

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('搜索单词失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取单词总数
  Future<int> getWordCount({String? jlptLevel}) async {
    try {
      final db = await _db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM words${jlptLevel != null ? ' WHERE jlpt_level = ?' : ''}',
        jlptLevel != null ? [jlptLevel] : null,
      );

      return result.first['count'] as int;
    } catch (e, stackTrace) {
      logger.error('获取单词总数失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 单词释义 ====================

  /// 获取单词的所有释义
  Future<List<WordMeaning>> getWordMeanings(int wordId) async {
    try {
      logger.database(
        'SELECT',
        table: 'word_meanings',
        data: {'word_id': wordId},
      );

      final db = await _db;
      final results = await db.query(
        'word_meanings',
        where: 'word_id = ?',
        whereArgs: [wordId],
        orderBy: 'definition_order ASC',
      );

      return results.map((map) => WordMeaning.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取单词释义失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 单词音频 ====================

  /// 获取单词的所有音频
  Future<List<WordAudio>> getWordAudios(int wordId) async {
    try {
      logger.database('SELECT', table: 'word_audio', data: {'word_id': wordId});

      final db = await _db;
      final results = await db.query(
        'word_audio',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      return results.map((map) => WordAudio.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取单词音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取单词的主要音频（第一个）
  Future<WordAudio?> getPrimaryWordAudio(int wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'word_audio',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return WordAudio.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取单词主要音频失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 例句 ====================

  /// 获取单词的所有例句
  Future<List<ExampleSentence>> getExampleSentences(int wordId) async {
    try {
      logger.database(
        'SELECT',
        table: 'example_sentences',
        data: {'word_id': wordId},
      );

      final db = await _db;
      final results = await db.query(
        'example_sentences',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      return results.map((map) => ExampleSentence.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取例句失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取例句的音频
  Future<ExampleAudio?> getExampleAudio(int exampleId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'example_audio',
        where: 'example_id = ?',
        whereArgs: [exampleId],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return ExampleAudio.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.error('获取例句音频失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 组合查询 ====================

  /// 获取单词的完整详情（包含释义、音频、例句）
  Future<WordDetail?> getWordDetail(int wordId) async {
    try {
      logger.info('获取单词详情: $wordId');

      // 1. 获取单词基本信息
      final word = await getWordById(wordId);
      if (word == null) {
        logger.warning('单词不存在: $wordId');
        return null;
      }

      // 2. 获取释义
      final meanings = await getWordMeanings(wordId);

      // 3. 获取音频
      final audios = await getWordAudios(wordId);

      // 4. 获取例句
      final sentences = await getExampleSentences(wordId);

      // 5. 为每个例句获取音频
      final examples = <ExampleSentenceWithAudio>[];
      for (final sentence in sentences) {
        final audio = await getExampleAudio(sentence.id);
        examples.add(
          ExampleSentenceWithAudio(sentence: sentence, audio: audio),
        );
      }

      logger.info(
        '单词详情获取成功: ${word.word} (${meanings.length}个释义, ${examples.length}个例句)',
      );

      return WordDetail(
        word: word,
        meanings: meanings,
        audios: audios,
        examples: examples,
      );
    } catch (e, stackTrace) {
      logger.error('获取单词详情失败', e, stackTrace);
      rethrow;
    }
  }

  /// 获取单词列表及其主要释义（用于列表显示）
  Future<List<Map<String, dynamic>>> getWordsWithMeanings({
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    try {
      logger.database('SELECT', table: 'words + word_meanings');

      final db = await _db;
      final sql =
          '''
        SELECT 
          w.*,
          wm.meaning_cn as primary_meaning
        FROM words w
        LEFT JOIN word_meanings wm ON w.id = wm.word_id AND wm.definition_order = 1
        ${jlptLevel != null ? 'WHERE w.jlpt_level = ?' : ''}
        ORDER BY w.id ASC
        ${limit != null ? 'LIMIT $limit' : ''}
        ${offset != null ? 'OFFSET $offset' : ''}
      ''';

      final results = await db.rawQuery(
        sql,
        jlptLevel != null ? [jlptLevel] : null,
      );

      return results;
    } catch (e, stackTrace) {
      logger.error('获取单词列表及释义失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 预加载查询 ====================

  /// 获取未学习的单词（用于预加载）
  ///
  /// 排除 study_words 表中 user_state > 0 的单词
  /// 支持排除指定 ID 列表
  ///
  /// [limit] 返回的单词数量，默认 20
  /// [excludeIds] 需要排除的单词 ID 列表，默认空列表
  Future<List<Word>> getUnlearnedWords({
    int limit = 20,
    List<int> excludeIds = const [],
  }) async {
    try {
      logger.database(
        'SELECT UNLEARNED',
        table: 'words',
        data: {'limit': limit, 'excludeIds': excludeIds},
      );

      final db = await _db;

      // 构建 WHERE 子句
      String whereClause =
          'id NOT IN (SELECT word_id FROM study_words WHERE user_state > 0)';

      if (excludeIds.isNotEmpty) {
        final excludeIdsStr = excludeIds.join(',');
        whereClause += ' AND id NOT IN ($excludeIdsStr)';
      }

      final results = await db.query(
        'words',
        where: whereClause,
        orderBy: 'id ASC',
        limit: limit,
      );

      logger.info('获取未学习单词成功: ${results.length} 个');
      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取未学习单词失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 随机查询 ====================

  /// 随机获取单词
  Future<List<Word>> getRandomWords({int count = 10, String? jlptLevel}) async {
    try {
      logger.database('SELECT RANDOM', table: 'words', data: {'count': count});

      final db = await _db;
      final results = await db.query(
        'words',
        where: jlptLevel != null ? 'jlpt_level = ?' : null,
        whereArgs: jlptLevel != null ? [jlptLevel] : null,
        orderBy: 'RANDOM()',
        limit: count,
      );

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('随机获取单词失败', e, stackTrace);
      rethrow;
    }
  }

  // ==================== 统计查询 ====================

  /// 获取各 JLPT 等级的单词数量
  Future<Map<String, int>> getWordCountByLevel() async {
    try {
      logger.database('SELECT COUNT GROUP BY', table: 'words');

      final db = await _db;
      final results = await db.rawQuery('''
        SELECT jlpt_level, COUNT(*) as count
        FROM words
        WHERE jlpt_level IS NOT NULL
        GROUP BY jlpt_level
        ORDER BY jlpt_level DESC
      ''');

      final countMap = <String, int>{};
      for (final row in results) {
        final level = row['jlpt_level'] as String;
        final count = row['count'] as int;
        countMap[level] = count;
      }

      return countMap;
    } catch (e, stackTrace) {
      logger.error('获取单词等级统计失败', e, stackTrace);
      rethrow;
    }
  }
}
