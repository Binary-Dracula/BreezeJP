import 'package:sqflite/sqflite.dart';

import '../../core/utils/app_logger.dart';
import '../models/sync_outbox_item.dart';

class SyncOutboxRepository {
  SyncOutboxRepository(this._dbProvider);

  final Future<Database> Function() _dbProvider;

  Future<Database> get _db async => await _dbProvider();

  Future<int> enqueue(SyncOutboxItem item) async {
    try {
      final db = await _db;
      final id = await db.insert(
        'sync_outbox',
        item.toMapForInsert(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      logger.dbInsert(
        table: 'sync_outbox',
        id: id,
        keyFields: {
          'syncUserId': item.syncUserId,
          'mutationId': item.mutationId,
          'entityType': item.entityType,
        },
      );
      return id;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<SyncOutboxItem>> getDispatchableItems(
    String syncUserId, {
    int limit = 50,
    int? nowAt,
  }) async {
    try {
      final db = await _db;
      final currentTime =
          nowAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final results = await db.query(
        'sync_outbox',
        where:
            'sync_user_id = ? AND status IN (?, ?) AND (next_retry_at IS NULL OR next_retry_at <= ?)',
        whereArgs: [syncUserId, 'pending', 'failed', currentTime],
        orderBy: 'created_at ASC',
        limit: limit,
      );

      logger.dbQuery(
        table: 'sync_outbox',
        where: 'sync_user_id=$syncUserId AND dispatchable=true',
        resultCount: results.length,
      );

      return results.map(SyncOutboxItem.fromMap).toList();
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'SELECT',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<int> countPending(String syncUserId) async {
    try {
      final db = await _db;
      final results = await db.rawQuery(
        '''
        SELECT COUNT(*) AS count
        FROM sync_outbox
        WHERE sync_user_id = ?
          AND status IN ('pending', 'failed', 'syncing')
        ''',
        [syncUserId],
      );
      return Sqflite.firstIntValue(results) ?? 0;
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'COUNT',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> markItemsSyncing(List<int> ids) async {
    if (ids.isEmpty) return;

    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final placeholders = List.filled(ids.length, '?').join(', ');
      await db.rawUpdate(
        'UPDATE sync_outbox SET status = ?, updated_at = ? WHERE id IN ($placeholders)',
        ['syncing', now, ...ids],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> markItemFailed(
    int id, {
    String? lastError,
    int? nextRetryAt,
  }) async {
    try {
      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.update(
        'sync_outbox',
        {
          'status': 'failed',
          'retry_count': const _IncrementExpression(1),
          'next_retry_at': nextRetryAt,
          'last_error': lastError,
          'updated_at': now,
        }..removeWhere((key, value) => value is _IncrementExpression),
        where: 'id = ?',
        whereArgs: [id],
      );

      await db.rawUpdate(
        'UPDATE sync_outbox SET retry_count = retry_count + 1 WHERE id = ?',
        [id],
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteItems(List<int> ids) async {
    if (ids.isEmpty) return;

    try {
      final db = await _db;
      final placeholders = List.filled(ids.length, '?').join(', ');
      final deletedRows = await db.rawDelete(
        'DELETE FROM sync_outbox WHERE id IN ($placeholders)',
        ids,
      );
      logger.dbDelete(table: 'sync_outbox', deletedRows: deletedRows);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'sync_outbox',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

class _IncrementExpression {
  const _IncrementExpression(this.value);

  final int value;
}
