import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/word_favorite.dart';

class WordFavoriteRepository {
  WordFavoriteRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  Future<WordFavorite?> getFavorite(int userId, String wordId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'user_word_favorites',
        where: 'user_id = ? AND word_id = ?',
        whereArgs: [userId, wordId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'user_word_favorites',
        where: 'user_id=$userId AND word_id=$wordId',
        resultCount: results.length,
      );

      if (results.isEmpty) {
        return null;
      }
      return WordFavorite.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'user_word_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> saveFavorite(WordFavorite favorite) async {
    try {
      final db = await _db;
      await db.insert(
        'user_word_favorites',
        favorite.toMapForInsert(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.dbInsert(
        table: 'user_word_favorites',
        id: favorite.id,
        keyFields: {
          'userId': favorite.userId,
          'wordId': favorite.wordId,
          'bookId': favorite.bookId,
        },
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'user_word_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteFavorite(int userId, String wordId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'user_word_favorites',
        where: 'user_id = ? AND word_id = ?',
        whereArgs: [userId, wordId],
      );

      logger.dbDelete(table: 'user_word_favorites', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'user_word_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<WordFavorite>> getAllByUser(int userId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'user_word_favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return results.map(WordFavorite.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT ALL',
        table: 'user_word_favorites',
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
        'user_word_favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      logger.dbDelete(table: 'user_word_favorites', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'user_word_favorites',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
