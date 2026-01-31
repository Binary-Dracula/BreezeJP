import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/daily_stat_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/repositories/study_log_repository.dart';
import 'package:breeze_jp/data/repositories/study_log_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';

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
  test('word SRS flow: seen -> learning -> reviews -> mastered', () async {
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

    const userId = 1;
    const wordId = 101;

    await command.ensureWordSeen(userId, wordId);
    final seen = await studyWordRepo.getStudyWord(userId, wordId);
    expect(seen, isNotNull);
    expect(seen!.userState, LearningStatus.seen);
    expect(seen.nextReviewAt, isNull);
    expect(seen.interval, isNull);
    expect(seen.easeFactor, isNull);
    expect(seen.stability, isNull);
    expect(seen.difficulty, isNull);
    expect(seen.totalReviews, 0);
    expect(studyLogRepo.logs, isEmpty);
    expect(dailyStats.learnedTotal, 0);
    expect(dailyStats.reviewedTotal, 0);

    await command.addWordToReview(userId, wordId);
    final learning = await studyWordRepo.getStudyWord(userId, wordId);
    expect(learning, isNotNull);
    expect(learning!.userState, LearningStatus.learning);
    expect(learning.nextReviewAt, isNotNull);
    expect(learning.interval, 1);
    expect(learning.easeFactor, closeTo(2.5, 0.001));
    expect(learning.stability, closeTo(0.0, 0.001));
    expect(learning.difficulty, closeTo(0.0, 0.001));
    expect(learning.totalReviews, 0);
    expect(
      studyLogRepo.logs.where((log) => log.logType == LogType.firstLearn).length,
      1,
    );
    expect(dailyStats.learnedTotal, 1);
    expect(dailyStats.reviewedTotal, 0);

    await command.addWordToReview(userId, wordId);
    expect(
      studyLogRepo.logs.where((log) => log.logType == LogType.firstLearn).length,
      1,
    );
    expect(dailyStats.learnedTotal, 1);

    await command.onWordReviewed(
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
    );
    final afterFirstReview = await studyWordRepo.getStudyWord(userId, wordId);
    expect(afterFirstReview, isNotNull);
    expect(afterFirstReview!.totalReviews, 1);
    expect(afterFirstReview.streak, 1);
    expect(afterFirstReview.failCount, 0);
    expect(afterFirstReview.interval, 1);
    expect(afterFirstReview.lastReviewedAt, isNotNull);
    expect(
      studyLogRepo.logs.where((log) => log.logType == LogType.review).length,
      1,
    );
    expect(dailyStats.reviewedTotal, 1);

    await command.onWordReviewed(
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
    );
    final afterSecondReview = await studyWordRepo.getStudyWord(userId, wordId);
    expect(afterSecondReview, isNotNull);
    expect(afterSecondReview!.totalReviews, 2);
    expect(afterSecondReview.streak, 2);
    expect(afterSecondReview.failCount, 0);
    expect(afterSecondReview.interval, 6);
    expect(dailyStats.reviewedTotal, 2);

    await command.onWordReviewed(
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.again,
    );
    final afterFail = await studyWordRepo.getStudyWord(userId, wordId);
    expect(afterFail, isNotNull);
    expect(afterFail!.totalReviews, 3);
    expect(afterFail.streak, 0);
    expect(afterFail.failCount, 1);
    expect(afterFail.interval, 0);
    expect(dailyStats.reviewedTotal, 3);

    await command.markWordAsMastered(userId, wordId);
    final mastered = await studyWordRepo.getStudyWord(userId, wordId);
    expect(mastered, isNotNull);
    expect(mastered!.userState, LearningStatus.mastered);
  });
}
