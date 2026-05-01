import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import 'active_user_query.dart';

class FavoriteQuery {
  FavoriteQuery(this._db, this._activeUserQuery);

  final Database _db;
  final ActiveUserQuery _activeUserQuery;

  Future<bool> isWordFavorited(String wordId) async {
    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return false;
    }

    final results = await _db.query(
      'user_word_favorites',
      columns: const ['word_id'],
      where: 'user_id = ? AND word_id = ?',
      whereArgs: [userId, wordId],
      limit: 1,
    );

    logger.dbQuery(
      table: 'user_word_favorites',
      where: 'user_id=$userId AND word_id=$wordId',
      resultCount: results.length,
    );
    return results.isNotEmpty;
  }

  Future<bool> isWordExampleFavorited(String exampleId) async {
    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return false;
    }

    final results = await _db.query(
      'user_word_example_favorites',
      columns: const ['example_id'],
      where: 'user_id = ? AND example_id = ?',
      whereArgs: [userId, exampleId],
      limit: 1,
    );

    logger.dbQuery(
      table: 'user_word_example_favorites',
      where: 'user_id=$userId AND example_id=$exampleId',
      resultCount: results.length,
    );
    return results.isNotEmpty;
  }

  Future<Set<String>> getFavoritedExampleIds(
    Iterable<String> exampleIds,
  ) async {
    final ids = exampleIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) {
      return const <String>{};
    }

    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return const <String>{};
    }

    final placeholders = List.filled(ids.length, '?').join(', ');
    final results = await _db.rawQuery(
      '''
        SELECT example_id
        FROM user_word_example_favorites
        WHERE user_id = ?
          AND example_id IN ($placeholders)
      ''',
      [userId, ...ids],
    );

    logger.dbQuery(
      table: 'user_word_example_favorites',
      where: 'user_id=$userId AND example_id IN (${ids.length})',
      resultCount: results.length,
    );

    return results.map((row) => row['example_id']).whereType<String>().toSet();
  }

  Future<String?> resolveBookIdForWord(String wordId) async {
    final contentRows = await _db.rawQuery(
      '''
        SELECT book_id
        FROM lesson_word_map
        WHERE word_id = ?
        ORDER BY book_sort_order ASC
        LIMIT 1
      ''',
      [wordId],
    );
    if (contentRows.isNotEmpty) {
      return contentRows.first['book_id'] as String?;
    }

    final userId = await _activeUserQuery.getActiveUserId();
    if (userId == null) {
      return null;
    }

    final stateRows = await _db.query(
      'study_words',
      columns: const ['book_id'],
      where: 'user_id = ? AND word_id = ?',
      whereArgs: [userId, wordId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    logger.dbQuery(
      table: 'lesson_word_map + study_words',
      where: 'word_id=$wordId, user_id=$userId',
      resultCount: contentRows.length + stateRows.length,
    );

    if (stateRows.isEmpty) {
      return null;
    }
    return stateRows.first['book_id'] as String?;
  }
}
