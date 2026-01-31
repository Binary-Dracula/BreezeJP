import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/data/commands/kana_command.dart';
import 'package:breeze_jp/data/commands/kana_command_provider.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';
import 'package:breeze_jp/domain/kana/kana_domain_event.dart';

class _ExpectedSm2Output {
  const _ExpectedSm2Output({
    required this.interval,
    required this.easeFactor,
  });

  final double interval;
  final double easeFactor;
}

class _InMemoryKanaRepository extends KanaRepository {
  _InMemoryKanaRepository() : super(() async => throw UnimplementedError());

  final Map<String, KanaLearningState> _states = {};
  int _nextId = 1;

  String _key(int userId, int kanaId) => '$userId:$kanaId';

  @override
  Future<KanaLearningState?> getKanaLearningState(
    int userId,
    int kanaId,
  ) async {
    return _states[_key(userId, kanaId)];
  }

  @override
  Future<int> insertKanaLearningState(KanaLearningState state) async {
    final id = _nextId++;
    final inserted = state.copyWith(id: id);
    _states[_key(state.userId, state.kanaId)] = inserted;
    return id;
  }

  @override
  Future<int> updateKanaLearningState(KanaLearningState state) async {
    _states[_key(state.userId, state.kanaId)] = state;
    return 1;
  }
}

void main() {
  setUpAll(() {
    logger.setTestMode(true);
  });

  test('kana SRS flow matches expected SM-2 results', () async {
    const userId = 1;
    const kanaId = 101;

    const expectedInitial = _ExpectedSm2Output(interval: 1.0, easeFactor: 2.5);
    const expectedReview1 = _ExpectedSm2Output(interval: 1.0, easeFactor: 2.5);
    const expectedReview2 = _ExpectedSm2Output(interval: 6.0, easeFactor: 2.5);
    const expectedReview3 = _ExpectedSm2Output(interval: 7.0, easeFactor: 2.35);
    const expectedReview4 = _ExpectedSm2Output(interval: 21.0, easeFactor: 2.6);

    final repo = _InMemoryKanaRepository();
    final container = ProviderContainer(
      overrides: [kanaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final command = container.read(kanaCommandProvider);

    final practiceStart = DateTime.now();
    final event = await command.onKanaPracticed(
      userId: userId,
      kanaId: kanaId,
    );
    final practiceEnd = DateTime.now();

    expect(event, isNotNull);
    expect(event, isA<KanaPracticed>());

    final initial = await repo.getKanaLearningState(userId, kanaId);
    expect(initial, isNotNull);
    expect(initial!.learningStatus, LearningStatus.learning);
    expect(initial.interval, closeTo(expectedInitial.interval, 0.0001));
    expect(initial.easeFactor, closeTo(expectedInitial.easeFactor, 0.0001));
    expect(initial.stability, closeTo(0.0, 0.0001));
    expect(initial.difficulty, closeTo(0.0, 0.0001));
    expect(initial.totalReviews, 0);
    expect(initial.streak, 0);
    expect(initial.failCount, 0);
    expect(initial.lastReviewedAt, isNull);
    _expectNextReviewAtSeconds(
      initial.nextReviewAt,
      practiceStart,
      practiceEnd,
      Duration(days: expectedInitial.interval.ceil()),
    );

    await _reviewAndAssert(
      command: command,
      repo: repo,
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.good,
      expected: expectedReview1,
      expectedReviews: 1,
      expectedStreak: 1,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      repo: repo,
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.good,
      expected: expectedReview2,
      expectedReviews: 2,
      expectedStreak: 2,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      repo: repo,
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.hard,
      expected: expectedReview3,
      expectedReviews: 3,
      expectedStreak: 3,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      repo: repo,
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.easy,
      expected: expectedReview4,
      expectedReviews: 4,
      expectedStreak: 4,
      expectedFailCount: 0,
    );

    final beforeMaster = await repo.getKanaLearningState(userId, kanaId);
    expect(beforeMaster, isNotNull);

    final masterEvent = await command.toggleKanaMastered(
      userId: userId,
      kanaId: kanaId,
    );

    expect(masterEvent, isNotNull);
    expect(masterEvent, isA<KanaMastered>());

    final mastered = await repo.getKanaLearningState(userId, kanaId);
    expect(mastered, isNotNull);
    expect(mastered!.learningStatus, LearningStatus.mastered);
    expect(mastered.interval, closeTo(expectedReview4.interval, 0.0001));
    expect(mastered.easeFactor, closeTo(expectedReview4.easeFactor, 0.0001));
    expect(mastered.totalReviews, 4);
    expect(mastered.streak, 4);
    expect(mastered.failCount, 0);
    expect(mastered.nextReviewAt, beforeMaster!.nextReviewAt);
    expect(mastered.lastReviewedAt, beforeMaster.lastReviewedAt);
    expect(mastered.updatedAt, greaterThanOrEqualTo(beforeMaster.updatedAt));
  });
}

Future<void> _reviewAndAssert({
  required KanaCommand command,
  required _InMemoryKanaRepository repo,
  required int userId,
  required int kanaId,
  required ReviewRating rating,
  required _ExpectedSm2Output expected,
  required int expectedReviews,
  required int expectedStreak,
  required int expectedFailCount,
}) async {
  final start = DateTime.now();
  await command.onKanaReviewed(
    userId: userId,
    kanaId: kanaId,
    rating: rating,
  );
  final end = DateTime.now();

  final state = await repo.getKanaLearningState(userId, kanaId);
  expect(state, isNotNull);
  expect(state!.learningStatus, LearningStatus.learning);
  expect(state.interval, closeTo(expected.interval, 0.0001));
  expect(state.easeFactor, closeTo(expected.easeFactor, 0.0001));
  expect(state.stability, closeTo(0.0, 0.0001));
  expect(state.difficulty, closeTo(0.0, 0.0001));
  expect(state.totalReviews, expectedReviews);
  expect(state.streak, expectedStreak);
  expect(state.failCount, expectedFailCount);
  _expectWithinSeconds(state.lastReviewedAt, start, end);
  _expectNextReviewAtSeconds(
    state.nextReviewAt,
    start,
    end,
    Duration(days: expected.interval.ceil()),
  );
}

void _expectWithinSeconds(
  int? value,
  DateTime start,
  DateTime end,
) {
  expect(value, isNotNull);
  final startSeconds = start.millisecondsSinceEpoch ~/ 1000;
  final endSeconds = end.millisecondsSinceEpoch ~/ 1000;
  expect(value! >= startSeconds, isTrue);
  expect(value <= endSeconds + 1, isTrue);
}

void _expectNextReviewAtSeconds(
  int? value,
  DateTime start,
  DateTime end,
  Duration offset,
) {
  expect(value, isNotNull);
  final startSeconds = start.millisecondsSinceEpoch ~/ 1000;
  final endSeconds = end.millisecondsSinceEpoch ~/ 1000;
  final offsetSeconds = offset.inSeconds;
  final earliest = startSeconds + offsetSeconds;
  final latest = endSeconds + offsetSeconds + 1;
  expect(value! >= earliest, isTrue);
  expect(value <= latest, isTrue);
}
