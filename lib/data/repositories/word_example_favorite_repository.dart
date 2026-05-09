import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/word_example_favorite.dart';

class WordExampleFavoriteRepository {
  WordExampleFavoriteRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  Future<WordExampleFavorite?> getFavorite(int userId, String exampleId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'user_word_example_favorites',
        where: 'user_id = ? AND example_id = ?',
        whereArgs: [userId, exampleId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'user_word_example_favorites',
        where: 'user_id=$userId AND example_id=$exampleId',
        resultCount: results.length,
      );

      if (results.isEmpty) {
        return null;
      }
      return WordExampleFavorite.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'user_word_example_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> saveFavorite(WordExampleFavorite favorite) async {
    try {
      final db = await _db;
      await db.insert(
        'user_word_example_favorites',
        favorite.toMapForInsert(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.dbInsert(
        table: 'user_word_example_favorites',
        id: favorite.id,
        keyFields: {
          'userId': favorite.userId,
          'exampleId': favorite.exampleId,
          'wordId': favorite.wordId,
        },
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'user_word_example_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteFavorite(int userId, String exampleId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'user_word_example_favorites',
        where: 'user_id = ? AND example_id = ?',
        whereArgs: [userId, exampleId],
      );

      logger.dbDelete(
        table: 'user_word_example_favorites',
        deletedRows: deletedRows,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'user_word_example_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<WordExampleFavorite>> getAllByUser(int userId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'user_word_example_favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return results.map(WordExampleFavorite.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT ALL',
        table: 'user_word_example_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteAllByUser(int userId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'user_word_example_favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(
        table: 'user_word_example_favorites',
        deletedRows: deletedRows,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'user_word_example_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
