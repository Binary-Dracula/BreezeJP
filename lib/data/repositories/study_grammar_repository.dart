import 'package:sqflite/sqflite.dart';
import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import '../models/study_grammar.dart';

class StudyGrammarRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<StudyGrammar?> getStudyGrammar(int userId, int grammarId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_grammars',
        where: 'user_id = ? AND grammar_id = ?',
        whereArgs: [userId, grammarId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'study_grammars',
        where: 'user_id=$userId AND grammar_id=$grammarId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return StudyGrammar.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> saveStudyGrammar(StudyGrammar studyGrammar) async {
    try {
      final db = await _db;
      final map = studyGrammar.toMap();
      // Remove ID if it's 0 (auto-increment) or let text ID handle it if using Insert (ConflictReplace)
      if (studyGrammar.id == 0) {
        map.remove('id');
      }

      await db.insert(
        'study_grammars',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.info(
        'Saved study grammar: ${studyGrammar.grammarId} for user ${studyGrammar.userId}',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT/REPLACE',
        table: 'study_grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<StudyGrammar>> getDueGrammars(int userId, int now) async {
    try {
      final db = await _db;
      final results = await db.query(
        'study_grammars',
        where: 'user_id = ? AND learning_status = 1 AND next_review_at <= ?',
        whereArgs: [userId, now],
      );

      logger.dbQuery(
        table: 'study_grammars',
        where: 'user_id=$userId AND due',
        resultCount: results.length,
      );

      return results.map((map) => StudyGrammar.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'study_grammars',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
