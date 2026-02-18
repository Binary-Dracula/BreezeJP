import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/grammar.dart';
import '../models/grammar_detail.dart';

import '../repositories/grammar_example_repository_provider.dart';
import '../repositories/grammar_meaning_repository_provider.dart';
import '../repositories/grammar_repository_provider.dart';
import '../repositories/study_grammar_repository_provider.dart';

final grammarReadQueriesProvider = Provider<GrammarReadQueries>((ref) {
  final db = ref.read(databaseProvider);
  return GrammarReadQueries(ref, db);
});

class GrammarReadQueries {
  GrammarReadQueries(this.ref, this._db);

  final Ref ref;
  final Database _db;

  /// 获取语法详情 (Grammar + Meanings + Examples + UserState)
  Future<GrammarDetail?> getGrammarDetail(int userId, int grammarId) async {
    try {
      final grammarRepo = ref.read(grammarRepositoryProvider);
      final meaningRepo = ref.read(grammarMeaningRepositoryProvider);
      final exampleRepo = ref.read(grammarExampleRepositoryProvider);
      final studyRepo = ref.read(studyGrammarRepositoryProvider);

      // 1. 获取语法条目
      final grammar = await grammarRepo.getGrammarById(grammarId);
      if (grammar == null) return null;

      // 2. 获取所有义项
      final meanings = await meaningRepo.getMeaningsByGrammarId(grammarId);

      // 3. 批量获取所有义项的例句（避免 N+1）
      final meaningIds = meanings.map((m) => m.id).toList();
      final examplesMap = await exampleRepo.getExamplesByMeaningIds(meaningIds);

      // 4. 将例句填充到对应义项中
      final meaningsWithExamples = meanings.map((m) {
        return m.copyWith(examples: examplesMap[m.id] ?? []);
      }).toList();

      // 5. 获取用户学习状态
      final studyState = await studyRepo.getStudyGrammar(userId, grammarId);
      final statusValue =
          studyState?.learningStatus ?? LearningStatus.seen.value;
      final status = LearningStatus.fromValue(statusValue);

      return GrammarDetail(
        grammar: grammar,
        meanings: meaningsWithExamples,
        userState: status,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars (detail)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取待复习的语法列表
  Future<List<Grammar>> getDueGrammars(int userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final studyRepo = ref.read(studyGrammarRepositoryProvider);
      final grammarRepo = ref.read(grammarRepositoryProvider);

      final dueStudyGrammars = await studyRepo.getDueGrammars(userId, now);
      if (dueStudyGrammars.isEmpty) return [];

      final ids = dueStudyGrammars.map((e) => e.grammarId).toList();
      return await grammarRepo.getGrammarsByIds(ids);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars (due)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取语法列表 (可分页，可过滤 JLPT)
  Future<List<Grammar>> getGrammarList({
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = _db;
      final whereClause = jlptLevel != null ? 'jlpt_level = ?' : null;
      final whereArgs = jlptLevel != null ? [jlptLevel] : null;

      final results = await db.query(
        'grammars',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id ASC',
        limit: limit,
        offset: offset,
      );

      return results.map((map) => Grammar.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars (list)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取未学习的语法 (用于探索流) (随机排序)
  Future<List<Grammar>> getUnlearnedGrammars({
    required int userId,
    int limit = 10,
    List<int> excludeIds = const [],
  }) async {
    try {
      final db = _db;
      final args = <Object>[userId];
      var excludeClause = '';

      if (excludeIds.isNotEmpty) {
        final placeholders = List.filled(excludeIds.length, '?').join(',');
        excludeClause = 'AND g.id NOT IN ($placeholders)';
        args.addAll(excludeIds);
      }

      final sql =
          '''
        SELECT g.*
        FROM grammars g
        LEFT JOIN study_grammars sg ON g.id = sg.grammar_id AND sg.user_id = ?
        WHERE (sg.learning_status IS NULL OR sg.learning_status = 0)
        $excludeClause
        ORDER BY RANDOM()
        LIMIT ?
      ''';

      args.add(limit);

      final results = await db.rawQuery(sql, args);

      return results.map((map) => Grammar.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars (unlearned)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取每个 JLPT 级别的语法数量
  Future<Map<String, int>> getGrammarCountsByLevel() async {
    try {
      final db = _db;
      final results = await db.rawQuery(
        'SELECT jlpt_level, COUNT(*) as count FROM grammars GROUP BY jlpt_level',
      );

      final counts = <String, int>{};
      for (final row in results) {
        final level = row['jlpt_level'] as String?;
        final count = row['count'] as int;
        if (level != null) {
          counts[level] = count;
        }
      }
      return counts;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammars (counts)',
        dbError: e,
        stackTrace: stackTrace,
      );
      // Return empty map on error to avoid breaking UI
      return {};
    }
  }
}
