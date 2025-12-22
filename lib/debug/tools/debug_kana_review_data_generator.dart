import 'dart:math';

import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/commands/active_user_command_provider.dart';
import '../../data/commands/debug/debug_kana_command_provider.dart';
import '../../data/commands/kana_command_provider.dart';
import '../../data/commands/study_session_command_provider.dart';
import '../../data/commands/session/session_scope.dart';
import '../../data/models/kana_log.dart';
import '../../data/queries/active_user_query_provider.dart';
import '../../data/queries/kana_query_provider.dart';

class DebugKanaReviewDataGenerator {
  static Future<void> generateMockKanaReviewQueueData({
    int minCount = 15,
    int maxCount = 25,
    bool clearExistingForUser = false,
  }) async {
    final container = ProviderContainer();
    try {
      final activeUserCommand = container.read(activeUserCommandProvider);
      await activeUserCommand.ensureActiveUser();

      final activeUserQuery = container.read(activeUserQueryProvider);
      final userId = await activeUserQuery.getActiveUserId();
      if (userId == null) {
        throw StateError('DebugKanaReviewDataGenerator: active user not found');
      }

      final kanaCommand = container.read(kanaCommandProvider);
      final debugKanaCommand = container.read(debugKanaCommandProvider);
      final kanaQuery = container.read(kanaQueryProvider);
      final session = container.read(studySessionCommandProvider).createSession(
            userId: userId,
            scope: SessionScope.kanaReview,
          );

      logger.info(
        'DebugKanaReviewDataGenerator: start userId=$userId minCount=$minCount maxCount=$maxCount clearExisting=$clearExistingForUser',
      );

      if (clearExistingForUser) {
        await debugKanaCommand.clearUserReviewData(userId: userId);
      }

      final lettersWithState =
          await kanaQuery.getAllKanaLettersWithState(userId);
      final allKanaIds = lettersWithState
          .map((item) => item.letter.id)
          .whereType<int>()
          .toList();
      if (allKanaIds.isEmpty) {
        throw StateError('DebugKanaReviewDataGenerator: kana_letters is empty');
      }

      final existingKanaIds = <int>{};
      if (!clearExistingForUser) {
        for (final item in lettersWithState) {
          if (item.learningState != null) {
            existingKanaIds.add(item.letter.id);
          }
        }
      }

      final availableKanaIds =
          allKanaIds.where((id) => !existingKanaIds.contains(id)).toList();
      final availableKanaCount = availableKanaIds.length;
      if (availableKanaCount <= 0) {
        throw StateError(
          'DebugKanaReviewDataGenerator: no available kana to insert (try clearExistingForUser=true)',
        );
      }

      final rng = Random();
      final effectiveMinCount =
          _clampInt(minCount, 1, availableKanaCount);
      final effectiveMaxCount = _clampInt(
        maxCount,
        effectiveMinCount,
        availableKanaCount,
      );
      final targetCount =
          rng.nextInt(effectiveMaxCount - effectiveMinCount + 1) +
          effectiveMinCount;

      availableKanaIds.shuffle(rng);
      final selectedKanaIds = availableKanaIds.take(targetCount).toList();
      if (selectedKanaIds.isEmpty) {
        throw StateError(
          'DebugKanaReviewDataGenerator: selectedKanaIds is empty',
        );
      }

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var logCount = 0;

      for (final kanaId in selectedKanaIds) {
        await kanaCommand.getOrCreateLearningState(userId, kanaId);

        final totalReviews = rng.nextInt(5) + 1; // [1..5]
        var runningInterval = _randomDouble(rng, 0.5, 5.0);
        var runningEaseFactor = _randomDouble(rng, 2.0, 2.7);
        final dueNextReviewAt =
            nowSeconds - _randomIntInclusive(rng, 60, 3600);

        for (var i = 0; i < totalReviews; i++) {
          final isFirstLearn = i == 0;
          final logType =
              isFirstLearn ? KanaLogType.firstLearn : KanaLogType.review;
          final questionType = isFirstLearn
              ? 'recall'
              : (['recall', 'audio', 'switchMode'][rng.nextInt(3)]);
          final rating = isFirstLearn
              ? (rng.nextBool() ? 2 : 3)
              : rng.nextInt(3) + 1;

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

          final nextReviewAtAfter = i == totalReviews - 1
              ? dueNextReviewAt
              : nowSeconds + (runningInterval * 86400).round();
          final durationMs = _randomIntInclusive(rng, 800, 8000);

          await kanaCommand.updateKanaReviewResult(
            userId: userId,
            kanaId: kanaId,
            rating: rating,
            newInterval: runningInterval,
            newEaseFactor: runningEaseFactor,
            nextReviewAt: nextReviewAtAfter,
          );

          await kanaCommand.addKanaLogQuick(
            userId: userId,
            kanaId: kanaId,
            logType: logType,
            rating: rating,
            algorithm: 1,
            intervalAfter: runningInterval,
            nextReviewAtAfter: nextReviewAtAfter,
            easeFactorAfter: runningEaseFactor,
            fsrsStabilityAfter: 0,
            fsrsDifficultyAfter: 0,
            questionType: questionType,
            durationMs: durationMs,
          );
          logCount += 1;

          if (!isFirstLearn) {
            await session.submitKanaReview(
              rating: rating,
              durationMs: durationMs,
            );
          }
        }
      }

      await session.flush();

      final dueCount = await kanaQuery.countDueKanaReviews(userId);
      logger.info(
        'DebugKanaReviewDataGenerator: inserted logs=$logCount dueCount=$dueCount',
      );
    } finally {
      container.dispose();
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
