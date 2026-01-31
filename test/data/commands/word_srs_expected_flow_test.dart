import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/data/commands/daily_stat_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/repositories/study_log_repository.dart';
import 'package:breeze_jp/data/repositories/study_log_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';

class _ExpectedSm2Output {
  const _ExpectedSm2Output({
    required this.interval,
    required this.easeFactor,
  });

  final double interval;
  final double easeFactor;

  int get storedInterval => interval.round();
}

class _InMemoryStudyWordRepository extends StudyWordRepository {
  _InMemoryStudyWordRepository() : super();

  final Map<String, StudyWord> _states = {};
  int _nextId = 1;

  String _key(int userId, int wordId) => '$userId:$wordId';

  @override
  Future<StudyWord?> getStudyWord(int userId, int wordId) async {
    return _states[_key(userId, wordId)];
  }

  @override
  Future<int> createStudyWord(StudyWord studyWord) async {
    final id = _nextId++;
    final stored = studyWord.copyWith(id: id);
    _states[_key(studyWord.userId, studyWord.wordId)] = stored;
    return id;
  }

  @override
  Future<int> createStudyWordIgnoreConflict(StudyWord studyWord) async {
    final key = _key(studyWord.userId, studyWord.wordId);
    if (_states.containsKey(key)) {
      return 0;
    }
    return createStudyWord(studyWord);
  }

  @override
  Future<void> updateStudyWord(StudyWord studyWord) async {
    _states[_key(studyWord.userId, studyWord.wordId)] = studyWord;
  }
}

class _InMemoryStudyLogRepository extends StudyLogRepository {
  _InMemoryStudyLogRepository() : super();

  final List<StudyLog> logs = [];
  int _nextId = 1;

  @override
  Future<int> insert(StudyLog log) async {
    final id = _nextId++;
    logs.add(log.copyWith(id: id));
    return id;
  }

  @override
  Future<bool> existsFirstLearn({
    required int userId,
    required int wordId,
  }) async {
    return logs.any(
      (log) =>
          log.userId == userId &&
          log.wordId == wordId &&
          log.logType == LogType.firstLearn,
    );
  }
}

class _FakeDailyStatCommand extends DailyStatCommand {
  _FakeDailyStatCommand(super.ref);

  int learnedTotal = 0;
  int reviewedTotal = 0;

  @override
  Future<void> applyLearningDelta({
    required int userId,
    required int learnedDelta,
    required int reviewedDelta,
  }) async {
    learnedTotal += learnedDelta;
    reviewedTotal += reviewedDelta;
  }
}

void main() {
  setUpAll(() {
    logger.setTestMode(true);
  });

  test('word SRS flow matches expected SM-2 results', () async {
    const userId = 1;
    const wordId = 101;

    final expectedInitial = _ExpectedSm2Output(
      interval: 1.0,
      easeFactor: 2.5,
    );
    final expectedReview1 = _ExpectedSm2Output(
      interval: 1.0,
      easeFactor: 2.5,
    );
    final expectedReview2 = _ExpectedSm2Output(
      interval: 6.0,
      easeFactor: 2.5,
    );
    final expectedReview3 = _ExpectedSm2Output(
      interval: 7.0,
      easeFactor: 2.35,
    );
    final expectedReview4 = _ExpectedSm2Output(
      interval: 21.0,
      easeFactor: 2.6,
    );

    final studyWordRepo = _InMemoryStudyWordRepository();
    final studyLogRepo = _InMemoryStudyLogRepository();
    late _FakeDailyStatCommand dailyStats;

    final container = ProviderContainer(
      overrides: [
        studyWordRepositoryProvider.overrideWithValue(studyWordRepo),
        studyLogRepositoryProvider.overrideWithValue(studyLogRepo),
        dailyStatCommandProvider.overrideWith(
          (ref) => dailyStats = _FakeDailyStatCommand(ref),
        ),
      ],
    );
    addTearDown(container.dispose);

    dailyStats = container.read(dailyStatCommandProvider) as _FakeDailyStatCommand;
    final command = container.read(wordCommandProvider);

    await command.ensureWordSeen(userId, wordId);
    final seen = await studyWordRepo.getStudyWord(userId, wordId);
    expect(seen, isNotNull);
    expect(seen!.userState, LearningStatus.seen);
    expect(seen.nextReviewAt, isNull);
    expect(seen.lastReviewedAt, isNull);
    expect(seen.interval, isNull);
    expect(seen.easeFactor, isNull);
    expect(seen.stability, isNull);
    expect(seen.difficulty, isNull);
    expect(seen.totalReviews, 0);
    expect(seen.streak, 0);
    expect(seen.failCount, 0);

    final addStart = DateTime.now();
    await command.addWordToReview(userId, wordId);
    final addEnd = DateTime.now();

    final learning = await studyWordRepo.getStudyWord(userId, wordId);
    expect(learning, isNotNull);
    expect(learning!.userState, LearningStatus.learning);
    expect(learning.interval, expectedInitial.storedInterval);
    expect(learning.easeFactor, closeTo(expectedInitial.easeFactor, 0.0001));
    expect(learning.stability, closeTo(0.0, 0.0001));
    expect(learning.difficulty, closeTo(0.0, 0.0001));
    expect(learning.totalReviews, 0);
    expect(learning.streak, 0);
    expect(learning.failCount, 0);
    expect(learning.lastReviewedAt, isNull);
    _expectNextReviewAt(
      learning.nextReviewAt,
      addStart,
      addEnd,
      Duration(days: expectedInitial.interval.ceil()),
    );

    expect(studyLogRepo.logs.length, 1);
    final firstLearnLog = studyLogRepo.logs.first;
    expect(firstLearnLog.logType, LogType.firstLearn);
    expect(firstLearnLog.rating, isNull);
    expect(firstLearnLog.intervalAfter, closeTo(expectedInitial.interval, 0.0001));
    expect(
      firstLearnLog.easeFactorAfter,
      closeTo(expectedInitial.easeFactor, 0.0001),
    );
    expect(firstLearnLog.algorithm, 1);
    expect(dailyStats.learnedTotal, 1);
    expect(dailyStats.reviewedTotal, 0);

    await _reviewAndAssert(
      command: command,
      studyWordRepo: studyWordRepo,
      studyLogRepo: studyLogRepo,
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
      expected: expectedReview1,
      expectedReviews: 1,
      expectedStreak: 1,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      studyWordRepo: studyWordRepo,
      studyLogRepo: studyLogRepo,
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
      expected: expectedReview2,
      expectedReviews: 2,
      expectedStreak: 2,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      studyWordRepo: studyWordRepo,
      studyLogRepo: studyLogRepo,
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.hard,
      expected: expectedReview3,
      expectedReviews: 3,
      expectedStreak: 3,
      expectedFailCount: 0,
    );

    await _reviewAndAssert(
      command: command,
      studyWordRepo: studyWordRepo,
      studyLogRepo: studyLogRepo,
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.easy,
      expected: expectedReview4,
      expectedReviews: 4,
      expectedStreak: 4,
      expectedFailCount: 0,
    );

    expect(dailyStats.learnedTotal, 1);
    expect(dailyStats.reviewedTotal, 4);

    final markStart = DateTime.now();
    await command.markWordAsMastered(userId, wordId);
    final markEnd = DateTime.now();

    final mastered = await studyWordRepo.getStudyWord(userId, wordId);
    expect(mastered, isNotNull);
    expect(mastered!.userState, LearningStatus.mastered);
    expect(mastered.nextReviewAt, isNull);
    expect(mastered.interval, expectedReview4.storedInterval);
    expect(mastered.easeFactor, closeTo(expectedReview4.easeFactor, 0.0001));
    expect(mastered.totalReviews, 4);
    expect(mastered.streak, 4);
    expect(mastered.failCount, 0);
    _expectWithin(mastered.lastReviewedAt, markStart, markEnd);

    expect(studyLogRepo.logs.length, 6);
    expect(studyLogRepo.logs.last.logType, LogType.markMastered);
  });
}

Future<void> _reviewAndAssert({
  required WordCommand command,
  required _InMemoryStudyWordRepository studyWordRepo,
  required _InMemoryStudyLogRepository studyLogRepo,
  required int userId,
  required int wordId,
  required ReviewRating rating,
  required _ExpectedSm2Output expected,
  required int expectedReviews,
  required int expectedStreak,
  required int expectedFailCount,
}) async {
  final start = DateTime.now();
  await command.onWordReviewed(
    userId: userId,
    wordId: wordId,
    rating: rating,
  );
  final end = DateTime.now();

  final state = await studyWordRepo.getStudyWord(userId, wordId);
  expect(state, isNotNull);
  expect(state!.userState, LearningStatus.learning);
  expect(state.interval, expected.storedInterval);
  expect(state.easeFactor, closeTo(expected.easeFactor, 0.0001));
  expect(state.stability, closeTo(0.0, 0.0001));
  expect(state.difficulty, closeTo(0.0, 0.0001));
  expect(state.totalReviews, expectedReviews);
  expect(state.streak, expectedStreak);
  expect(state.failCount, expectedFailCount);
  _expectWithin(state.lastReviewedAt, start, end);
  _expectNextReviewAt(
    state.nextReviewAt,
    start,
    end,
    Duration(days: expected.interval.ceil()),
  );

  final lastLog = studyLogRepo.logs.last;
  expect(lastLog.logType, LogType.review);
  expect(lastLog.rating, rating);
  expect(lastLog.intervalAfter, closeTo(expected.interval, 0.0001));
  expect(lastLog.easeFactorAfter, closeTo(expected.easeFactor, 0.0001));
  expect(lastLog.algorithm, 1);
}

void _expectWithin(DateTime? value, DateTime start, DateTime end) {
  expect(value, isNotNull);
  expect(!value!.isBefore(start), isTrue);
  expect(!value.isAfter(end), isTrue);
}

void _expectNextReviewAt(
  DateTime? value,
  DateTime start,
  DateTime end,
  Duration offset,
) {
  expect(value, isNotNull);
  final earliest = start.add(offset);
  final latest = end.add(offset);
  expect(!value!.isBefore(earliest), isTrue);
  expect(!value.isAfter(latest), isTrue);
}
