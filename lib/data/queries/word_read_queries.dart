import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/read/word_list_item.dart';
import '../models/example_audio.dart';
import '../models/word.dart';
import '../models/word_choice.dart';
import '../models/word_detail.dart';
import '../models/word_meaning.dart';
import '../models/word_with_relation.dart';
import '../repositories/example_audio_repository_provider.dart';
import '../repositories/example_repository_provider.dart';
import '../repositories/word_audio_repository_provider.dart';
import '../repositories/word_meaning_repository_provider.dart';
import '../repositories/word_repository_provider.dart';

final wordReadQueriesProvider = Provider<WordReadQueries>((ref) {
  final db = ref.read(databaseProvider);
  return WordReadQueries(ref, db);
});

/// 单词 Read 查询层（组合查询/场景查询）
class WordReadQueries {
  WordReadQueries(this.ref, this._db);

  final Ref ref;
  final Database _db;

  /// 获取单词的完整详情（包含释义、音频、例句）
  Future<WordDetail?> getWordDetail(int wordId) async {
    try {
      final wordRepository = ref.read(wordRepositoryProvider);
      final meaningRepository = ref.read(wordMeaningRepositoryProvider);
      final audioRepository = ref.read(wordAudioRepositoryProvider);
      final exampleRepository = ref.read(exampleRepositoryProvider);
      final exampleAudioRepository = ref.read(exampleAudioRepositoryProvider);

      // 1) 获取单词基本信息
      final word = await wordRepository.getWordById(wordId);
      if (word == null) {
        logger.warning('单词不存在: $wordId');
        return null;
      }

      // 2) 获取释义
      final meanings = await meaningRepository.getWordMeanings(wordId);

      // 3) 获取音频
      final audios = await audioRepository.getWordAudios(wordId);

      // 4) 获取例句
      final sentences = await exampleRepository.getExampleSentences(wordId);

      // 5) 批量获取例句音频
      final exampleIds = sentences.map((s) => s.id).toList();
      final exampleAudios = await exampleAudioRepository
          .getExampleAudioByExampleIds(exampleIds);
      final audioByExampleId = <int, ExampleAudio>{
        for (final audio in exampleAudios) audio.exampleId: audio,
      };

      final examples = <ExampleSentenceWithAudio>[
        for (final sentence in sentences)
          ExampleSentenceWithAudio(
            sentence: sentence,
            audio: audioByExampleId[sentence.id],
          ),
      ];

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
      logger.dbError(
        operation: 'SELECT',
        table: 'words (detail)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取单词列表及其主要释义（用于列表显示）
  Future<List<WordListItem>> getWordListItems({
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = _db;
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

      logger.dbQuery(
        table: 'words + word_meanings',
        where: jlptLevel != null ? 'jlpt_level = $jlptLevel' : null,
        resultCount: results.length,
      );

      return results.map((row) {
        return WordListItem(
          word: Word.fromMap(row),
          primaryMeaning: row['primary_meaning'] as String?,
        );
      }).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words + word_meanings',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取未学习的单词（用于预加载）
  Future<List<Word>> getUnlearnedWords({
    required int userId,
    int limit = 20,
    List<int> excludeIds = const [],
  }) async {
    try {
      final db = _db;
      final whereArgs = <Object>[userId];
      var whereClause =
          'id NOT IN (SELECT word_id FROM study_words WHERE user_id = ? AND user_state > 0)';

      if (excludeIds.isNotEmpty) {
        final placeholders = List.filled(excludeIds.length, '?').join(',');
        whereClause += ' AND id NOT IN ($placeholders)';
        whereArgs.addAll(excludeIds);
      }

      final results = await db.query(
        'words',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'words',
        where: 'unlearned userId=$userId (excludeIds: ${excludeIds.length})',
        resultCount: results.length,
      );

      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 随机获取未掌握单词（包含释义，用于初始选择）
  /// 筛选条件：user_state IS NULL OR user_state IN (0, 1)
  Future<List<WordChoice>> getRandomUnmasteredWordsWithMeaning({
    required int userId,
    int count = 5,
  }) async {
    try {
      final db = _db;

      final wordIdRows = await db.rawQuery(
        '''
        SELECT w.id
        FROM words w
        LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
        WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
        ORDER BY RANDOM()
        LIMIT ?
      ''',
        [userId, count],
      );

      final wordIds = wordIdRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      logger.dbQuery(
        table: 'words',
        where: 'unmastered userId=$userId RANDOM() limit $count',
        resultCount: wordIds.length,
      );

      if (wordIds.isEmpty) return [];

      final placeholders = List.filled(wordIds.length, '?').join(',');
      final wordRows = await db.query(
        'words',
        where: 'id IN ($placeholders)',
        whereArgs: wordIds,
      );
      final wordsById = <int, Word>{
        for (final row in wordRows) (row['id'] as int): Word.fromMap(row),
      };

      final meaningRepository = ref.read(wordMeaningRepositoryProvider);
      final meanings = await meaningRepository.getWordMeaningsByWordIds(
        wordIds,
      );
      final meaningsByWordId = <int, List<WordMeaning>>{};
      for (final meaning in meanings) {
        meaningsByWordId.putIfAbsent(meaning.wordId, () => []).add(meaning);
      }

      final choices = <WordChoice>[];
      for (final wordId in wordIds) {
        final word = wordsById[wordId];
        if (word == null) continue;
        final wordMeanings = meaningsByWordId[wordId] ?? const [];
        choices.add(WordChoice(word: word, meanings: wordMeanings));
      }

      return choices;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'words + word_meanings',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取单词的关联词（过滤已掌握）
  /// 筛选条件：user_state IS NULL OR user_state IN (0, 1)
  Future<List<WordWithRelation>> getRelatedWords({
    required int userId,
    required int wordId,
  }) async {
    try {
      final db = _db;
      final results = await db.rawQuery(
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

      logger.dbQuery(
        table: 'word_relations + words',
        where: 'word_id = $wordId (userId=$userId, unmastered)',
        resultCount: results.length,
      );

      return results.map((map) => WordWithRelation.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'word_relations',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
