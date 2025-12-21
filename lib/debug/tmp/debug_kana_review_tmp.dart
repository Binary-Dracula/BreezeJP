import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/commands/active_user_command.dart';
import '../../data/commands/active_user_command_provider.dart';
import '../../data/commands/kana_command.dart';
import '../../data/commands/kana_command_provider.dart';
import '../../data/models/kana_learning_state.dart';
import '../../data/models/kana_log.dart';
import '../../data/models/user.dart';
import '../../data/queries/active_user_query.dart';
import '../../data/queries/active_user_query_provider.dart';
import '../../data/queries/kana_query.dart';
import '../../data/queries/kana_query_provider.dart';

final debugKanaReviewTmpProvider = Provider<DebugKanaReviewTmp>((ref) {
  return DebugKanaReviewTmp(ref);
});

class DebugKanaReviewTmp {
  DebugKanaReviewTmp(this.ref);

  final Ref ref;

  KanaQuery get _kanaQuery => ref.read(kanaQueryProvider);
  KanaCommand get _kanaCommand => ref.read(kanaCommandProvider);
  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  ActiveUserQuery get _activeUserQuery => ref.read(activeUserQueryProvider);

  Future<User> _getActiveUser() async {
    final ensured = await _activeUserCommand.ensureActiveUser();
    final user = await _activeUserQuery.getActiveUser();
    return user ?? ensured;
  }

  Future<Map<String, dynamic>> simulateReviewSequence(
    int userId,
    int kanaId,
    List<int> ratings, {
    String questionType = 'debug',
    int? forceAlgorithm,
  }) async {
    final activeUser = await _getActiveUser();
    final baseAlgorithm = activeUser.id == userId
        ? _extractAlgorithm(activeUser)
        : 1;
    final algorithm = forceAlgorithm ?? baseAlgorithm;

    for (final rating in ratings) {
      final learningState = await _kanaQuery.getKanaLearningState(
        userId,
        kanaId,
      );
      if (learningState == null) {
        throw StateError(
          'simulateReviewSequence: learningState not found for userId=$userId kanaId=$kanaId',
        );
      }
      final srs = _computeSrsResult(learningState, rating, algorithm);

      await _kanaCommand.updateKanaReviewResult(
        userId: userId,
        kanaId: kanaId,
        rating: rating,
        newInterval: srs.newInterval,
        newEaseFactor: srs.newEaseFactor,
        nextReviewAt: srs.nextReviewAt,
      );

      await _kanaCommand.addKanaLogQuick(
        userId: userId,
        kanaId: kanaId,
        logType: KanaLogType.review,
        rating: rating,
        algorithm: algorithm,
        intervalAfter: srs.newInterval,
        nextReviewAtAfter: srs.nextReviewAt,
        easeFactorAfter: srs.newEaseFactor,
        fsrsStabilityAfter: srs.newStability,
        fsrsDifficultyAfter: srs.newDifficulty,
        questionType: questionType,
      );
    }

    final finalState = await _kanaQuery.getKanaLearningState(userId, kanaId);
    final logs = await _kanaQuery.getKanaLogs(userId, kanaId);
    return {
      'finalState': finalState,
      'logs': logs.map((item) => item.log).toList(),
    };
  }

  _DebugSrsResult _computeSrsResult(
    KanaLearningState learningState,
    int rating,
    int algorithm,
  ) {
    if (algorithm == 2) {
      return _DebugSrsResult(
        newInterval: max(1, learningState.interval),
        newEaseFactor: learningState.easeFactor,
        nextReviewAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
        newStability: learningState.stability,
        newDifficulty: learningState.difficulty,
      );
    }

    return _sm2(learningState, rating);
  }

  _DebugSrsResult _sm2(KanaLearningState learningState, int rating) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    double interval = learningState.interval;
    double ef = learningState.easeFactor;

    if (rating == 1) {
      ef = max(1.3, ef - 0.20);
      interval = 0;
      return _DebugSrsResult(
        newInterval: interval,
        newEaseFactor: ef,
        nextReviewAt: now + 600,
      );
    }

    if (rating == 2) {
      if (interval == 0) {
        interval = 1;
      } else {
        interval = interval * ef;
      }
      return _DebugSrsResult(
        newInterval: interval,
        newEaseFactor: ef,
        nextReviewAt: now + (interval * 86400).toInt(),
      );
    }

    ef = ef + 0.05;
    interval = max(1, interval * ef * 1.3);
    return _DebugSrsResult(
      newInterval: interval,
      newEaseFactor: ef,
      nextReviewAt: now + (interval * 86400).toInt(),
    );
  }

  int _extractAlgorithm(User user) {
    if (user.settings == null) return 1;
    try {
      final map = jsonDecode(user.settings!) as Map<String, dynamic>;
      final raw = map['srsAlgorithm'] ?? map['srs_algorithm'];
      if (raw is num) {
        final value = raw.toInt();
        if (value == 2) return 2;
      }
    } catch (_) {
      // ignore parse errors, fallback to default
    }
    return 1;
  }
}

class _DebugSrsResult {
  final double newInterval;
  final double newEaseFactor;
  final int nextReviewAt;
  final double? newStability;
  final double? newDifficulty;

  _DebugSrsResult({
    required this.newInterval,
    required this.newEaseFactor,
    required this.nextReviewAt,
    this.newStability,
    this.newDifficulty,
  });
}
