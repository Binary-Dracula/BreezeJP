import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/sync_state.dart';

class SyncStateRepository {
  SyncStateRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  Future<SyncState?> getState(String syncUserId) async {
    try {
      final db = await _db;
      final results = await db.query(
        'sync_state',
        where: 'sync_user_id = ?',
        whereArgs: [syncUserId],
        limit: 1,
      );

      logger.dbQuery(
        table: 'sync_state',
        where: 'sync_user_id=$syncUserId',
        resultCount: results.length,
      );

      if (results.isEmpty) return null;
      return SyncState.fromMap(results.first);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'sync_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> upsertState(SyncState state) async {
    try {
      final db = await _db;
      await db.insert(
        'sync_state',
        state.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'sync_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteState(String syncUserId) async {
    try {
      final db = await _db;
      final deletedRows = await db.delete(
        'sync_state',
        where: 'sync_user_id = ?',
        whereArgs: [syncUserId],
      );

      logger.dbDelete(table: 'sync_state', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'sync_state',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
