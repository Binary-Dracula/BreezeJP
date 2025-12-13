import 'dart:math';

import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/data/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class DebugKanaReviewDataGenerator {
  static Future<void> generateMockKanaReviewQueueData({
    int minCount = 15,
    int maxCount = 25,
    bool clearExistingForUser = false,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rng = Random();

    final userId = await _getCurrentUserId(db);
    await _ensureUserExists(db, userId);

    logger.info(
      'DebugKanaReviewDataGenerator: start userId=$userId minCount=$minCount maxCount=$maxCount clearExisting=$clearExistingForUser',
    );

    await db.transaction((txn) async {
      if (clearExistingForUser) {
        final deletedLogs = await txn.delete(
          'kana_logs',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        final deletedStates = await txn.delete(
          'kana_learning_state',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        logger.info(
          'DebugKanaReviewDataGenerator: cleared user data logs=$deletedLogs states=$deletedStates',
        );
      }

      final allKanaRows = await txn.query('kana_letters', columns: ['id']);
      final allKanaIds = allKanaRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();
      if (allKanaIds.isEmpty) {
        throw StateError('DebugKanaReviewDataGenerator: kana_letters is empty');
      }

      final existingKanaIds = <int>{};
      if (!clearExistingForUser) {
        final existingRows = await txn.query(
          'kana_learning_state',
          columns: ['kana_id'],
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (final row in existingRows) {
          final kanaId = row['kana_id'];
          if (kanaId is int) existingKanaIds.add(kanaId);
        }
      }

      allKanaIds.shuffle(rng);

      final availableKanaIds = allKanaIds
          .where((kanaId) => !existingKanaIds.contains(kanaId))
          .toList();
      final availableKanaCount = availableKanaIds.length;
      if (availableKanaCount <= 0) {
        throw StateError(
          'DebugKanaReviewDataGenerator: no available kana to insert (try clearExistingForUser=true)',
        );
      }

      final effectiveMinCount = _clampInt(minCount, 1, availableKanaCount);
      final effectiveMaxCount = _clampInt(
        maxCount,
        effectiveMinCount,
        availableKanaCount,
      );
      final targetCount =
          rng.nextInt(effectiveMaxCount - effectiveMinCount + 1) +
          effectiveMinCount;

      final selectedKanaIds = availableKanaIds.take(targetCount).toList();

      if (selectedKanaIds.isEmpty) {
        throw StateError(
          'DebugKanaReviewDataGenerator: selectedKanaIds is empty',
        );
      }

      final stateInserts = <Map<String, Object?>>[];
      final logInserts = <Map<String, Object?>>[];

      for (final kanaId in selectedKanaIds) {
        final totalReviews = rng.nextInt(5) + 1; // [1..5]
        final streak = rng.nextInt(4); // [0..3]
        final nextReviewAt = now - _randomIntInclusive(rng, 60, 3600);

        final baseTime = now - _randomIntInclusive(rng, 2 * 86400, 7 * 86400);
        final logTimes = <int>[baseTime];
        for (var i = 1; i < totalReviews; i++) {
          final nextTime = logTimes.last + _randomIntInclusive(rng, 600, 7200);
          logTimes.add(min(nextTime, now - 1));
        }

        var runningInterval = _randomDouble(rng, 0.5, 5.0);
        var runningEaseFactor = _randomDouble(rng, 2.0, 2.7);
        var failCount = 0;

        for (var i = 0; i < totalReviews; i++) {
          final isFirstLearn = i == 0;
          final logType = isFirstLearn ? 1 : 2;
          final questionType = isFirstLearn
              ? 'recall'
              : (['recall', 'audio', 'switchMode'][rng.nextInt(3)]);
          final rating = isFirstLearn
              ? (rng.nextBool() ? 2 : 3)
              : rng.nextInt(3) + 1;

          if (!isFirstLearn && rating == 1) {
            failCount += 1;
          }

          runningInterval = _clampDouble(
            runningInterval + _randomDouble(rng, -0.2, 0.8),
            0.5,
            5.0,
          );
          runningEaseFactor = _clampDouble(
            runningEaseFactor + _randomDouble(rng, -0.05, 0.05),
            2.0,
            2.7,
          );

          final createdAt = logTimes[i];
          final nextReviewAtAfter = i == totalReviews - 1
              ? nextReviewAt
              : createdAt + (runningInterval * 86400).round();

          logInserts.add({
            'user_id': userId,
            'kana_id': kanaId,
            'log_type': logType,
            'rating': rating,
            'algorithm': 1,
            'interval_after': runningInterval,
            'next_review_at_after': nextReviewAtAfter,
            'ease_factor_after': runningEaseFactor,
            'fsrs_stability_after': 0,
            'fsrs_difficulty_after': 0,
            'duration_ms': _randomIntInclusive(rng, 800, 8000),
            'question_type': questionType,
            'created_at': createdAt,
          });
        }

        final lastReviewedAt = logTimes.last;
        final createdAt = max(
          1,
          baseTime - _randomIntInclusive(rng, 600, 7200),
        );

        stateInserts.add({
          'user_id': userId,
          'kana_id': kanaId,
          'learning_status': 1,
          'next_review_at': nextReviewAt,
          'last_reviewed_at': lastReviewedAt,
          'streak': streak,
          'total_reviews': totalReviews,
          'fail_count': failCount,
          'interval': runningInterval,
          'ease_factor': runningEaseFactor,
          'stability': 0,
          'difficulty': 0,
          'created_at': createdAt,
          'updated_at': now,
        });
      }

      final batch = txn.batch();
      for (final state in stateInserts) {
        batch.insert(
          'kana_learning_state',
          state,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final log in logInserts) {
        batch.insert(
          'kana_logs',
          log,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);

      logger.info(
        'DebugKanaReviewDataGenerator: inserted states=${stateInserts.length} logs=${logInserts.length}',
      );
    });

    final dueCountResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt
      FROM kana_learning_state
      WHERE user_id = ?
        AND learning_status = 1
        AND next_review_at <= ?
    ''',
      [userId, now],
    );
    final dueCount = (dueCountResult.first['cnt'] as int?) ?? 0;
    logger.info('DebugKanaReviewDataGenerator: done dueCount=$dueCount');
  }

  static Future<int> _getCurrentUserId(Database db) async {
    final rows = await db.query(
      'app_state',
      columns: ['current_user_id'],
      limit: 1,
    );
    final userId = rows.isNotEmpty
        ? rows.first['current_user_id'] as int?
        : null;
    if (userId == null) {
      throw StateError(
        'DebugKanaReviewDataGenerator: current_user_id not found in app_state',
      );
    }
    return userId;
  }

  static Future<void> _ensureUserExists(Database db, int userId) async {
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'DebugKanaReviewDataGenerator: user not found for current_user_id=$userId',
      );
    }
  }

  static int _clampInt(int value, int minValue, int maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }

  static int _randomIntInclusive(Random rng, int minValue, int maxValue) {
    if (minValue >= maxValue) return minValue;
    return rng.nextInt(maxValue - minValue + 1) + minValue;
  }

  static double _randomDouble(Random rng, double minValue, double maxValue) {
    if (minValue >= maxValue) return minValue;
    return rng.nextDouble() * (maxValue - minValue) + minValue;
  }

  static double _clampDouble(double value, double minValue, double maxValue) {
    if (value < minValue) return minValue;
    if (value > maxValue) return maxValue;
    return value;
  }
}

Future<void> generateMockKanaReviewQueueData({
  int minCount = 15,
  int maxCount = 25,
  bool clearExistingForUser = false,
}) {
  return DebugKanaReviewDataGenerator.generateMockKanaReviewQueueData(
    minCount: minCount,
    maxCount: maxCount,
    clearExistingForUser: clearExistingForUser,
  );
}
