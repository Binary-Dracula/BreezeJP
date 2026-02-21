import 'package:sqflite/sqflite.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/read/grammar_book_item.dart';

/// 语法本查询层（只读）
/// 联表查询 study_grammars + grammars
class GrammarBookQuery {
  GrammarBookQuery(this._db);

  final Database _db;

  /// 获取语法本列表项（分页 + 按状态筛选 + 可选搜索）
  ///
  /// [userId] 用户 ID
  /// [status] 学习状态（learning / mastered）
  /// [limit] 每页数量
  /// [offset] 偏移量
  /// [searchQuery] 可选搜索关键词（语法标题）
  Future<List<GrammarBookItem>> getGrammarBookItems({
    required int userId,
    required LearningStatus status,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    try {
      final whereArgs = <Object>[userId, status.value];
      var searchClause = '';

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final keyword = '%${searchQuery.trim()}%';
        searchClause = '''
          AND g.title LIKE ?
        ''';
        whereArgs.add(keyword);
      }

      final sql =
          '''
        SELECT
          sg.id AS study_grammar_id,
          sg.grammar_id,
          g.title,
          g.jlpt_level,
          sg.learning_status,
          sg.updated_at
        FROM study_grammars sg
        INNER JOIN grammars g ON sg.grammar_id = g.id
        WHERE sg.user_id = ? AND sg.learning_status = ?
        $searchClause
        GROUP BY sg.id
        ORDER BY sg.updated_at DESC
        LIMIT $limit OFFSET $offset
      ''';

      final results = await _db.rawQuery(sql, whereArgs);

      logger.dbQuery(
        table: 'study_grammars + grammars',
        where:
            'user_id=$userId, learning_status=${status.name}, search=$searchQuery',
        resultCount: results.length,
      );

      return results.map((row) => GrammarBookItem.fromMap(row)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'grammar_book (join)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 获取各状态的语法数量
  ///
  /// 返回 `{LearningStatus.learning: count, LearningStatus.mastered: count}`
  Future<Map<LearningStatus, int>> getStatusCounts({
    required int userId,
    String? searchQuery,
  }) async {
    try {
      final whereArgs = <Object>[
        userId,
        LearningStatus.learning.value,
        LearningStatus.mastered.value,
      ];
      var searchClause = '';

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final keyword = '%${searchQuery.trim()}%';
        searchClause = '''
          AND g.title LIKE ?
        ''';
        whereArgs.add(keyword);
      }

      final sql =
          '''
        SELECT sg.learning_status, COUNT(*) AS count
        FROM study_grammars sg
        INNER JOIN grammars g ON sg.grammar_id = g.id
        WHERE sg.user_id = ?
          AND sg.learning_status IN (?, ?)
          $searchClause
        GROUP BY sg.learning_status
      ''';

      final results = await _db.rawQuery(sql, whereArgs);

      logger.dbQuery(
        table: 'study_grammars (status counts)',
        where: 'user_id=$userId, search=$searchQuery',
        resultCount: results.length,
      );

      final counts = <LearningStatus, int>{
        LearningStatus.learning: 0,
        LearningStatus.mastered: 0,
      };

      for (final row in results) {
        final status = LearningStatus.fromValue(row['learning_status'] as int);
        counts[status] = row['count'] as int;
      }

      return counts;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_grammars (status counts)',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
