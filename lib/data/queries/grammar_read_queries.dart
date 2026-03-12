import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database_provider.dart';
import '../models/grammar.dart';
import '../models/grammar_detail.dart';

import '../repositories/grammar_example_repository_provider.dart';
import '../repositories/grammar_meaning_repository_provider.dart';
import '../repositories/grammar_context_repository_provider.dart';
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
      final contextRepo = ref.read(grammarContextRepositoryProvider);
      final exampleRepo = ref.read(grammarExampleRepositoryProvider);
      final studyRepo = ref.read(studyGrammarRepositoryProvider);

      // 1. 获取语法条目
      final grammar = await grammarRepo.getGrammarById(grammarId);
      if (grammar == null) return null;

      // 2. 获取所有义项
      final meanings = await meaningRepo.getMeaningsByGrammarId(grammarId);

      // 3. 获取所有场景提示
      final contexts = await contextRepo.getContextsByGrammarId(grammarId);

      // 4. 获取所有例句 (现在直接根据 grammarId 挂载)
      final examples = await exampleRepo.getExamplesByGrammarId(grammarId);

      // 5. 获取用户学习状态
      final studyState = await studyRepo.getStudyGrammar(userId, grammarId);
      final statusValue =
          studyState?.learningStatus ?? LearningStatus.seen.value;
      final status = LearningStatus.fromValue(statusValue);

      return GrammarDetail(
        grammar: grammar,
        meanings: meanings,
        contexts: contexts,
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
    int? userId,
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = _db;
      
      if (userId == null) {
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
      }

      // 需要带上学习状态
      final args = <Object>[userId];
      var whereClause = '';
      if (jlptLevel != null) {
        whereClause = 'WHERE g.jlpt_level = ?';
        args.add(jlptLevel);
      }

      final sql = '''
        SELECT g.*, sg.learning_status
        FROM grammars g
        LEFT JOIN study_grammars sg ON g.id = sg.grammar_id AND sg.user_id = ?
        $whereClause
        ORDER BY g.id ASC
        LIMIT ? OFFSET ?
      ''';
      
      args.add(limit ?? 1000); // 默认足够大的 limit
      args.add(offset ?? 0);

      final results = await db.rawQuery(sql, args);

      return results.map((map) {
        final grammar = Grammar.fromMap(map);
        final statusValue = map['learning_status'] as int?;
        final status = statusValue != null 
            ? LearningStatus.fromValue(statusValue) 
            : null;
        return grammar.copyWith(userState: status);
      }).toList();
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
