import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/grammar.dart';
import '../models/grammar_detail.dart';

import '../repositories/grammar_example_repository_provider.dart';
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

  /// 获取语法详情 (Grammar + Examples + UserState)
  Future<GrammarDetail?> getGrammarDetail(int userId, int grammarId) async {
    try {
      final grammarRepo = ref.read(grammarRepositoryProvider);
      final exampleRepo = ref.read(grammarExampleRepositoryProvider);
      final studyRepo = ref.read(studyGrammarRepositoryProvider);

      final grammar = await grammarRepo.getGrammarById(grammarId);
      if (grammar == null) return null;

      final examples = await exampleRepo.getExamplesByGrammarId(grammarId);
      final studyState = await studyRepo.getStudyGrammar(userId, grammarId);

      final statusValue =
          studyState?.learningStatus ?? LearningStatus.seen.value;
      final status = LearningStatus.fromValue(statusValue);

      return GrammarDetail(
        grammar: grammar,
        examples: examples,
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
}
