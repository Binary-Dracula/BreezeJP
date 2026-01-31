import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/daily_stat_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/repositories/study_log_repository.dart';
import 'package:breeze_jp/data/repositories/study_log_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';

class _SqliteStudyWordRepository extends StudyWordRepository {
  _SqliteStudyWordRepository(this.db);

  final Database db;

  @override
  Future<StudyWord?> getStudyWord(int userId, int wordId) async {
    final results = await db.query(
      'study_words',
      where: 'user_id = ? AND word_id = ?',
      whereArgs: [userId, wordId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return StudyWord.fromMap(results.first);
  }

  @override
  Future<int> createStudyWord(StudyWord studyWord) async {
    return db.insert('study_words', studyWord.toMapForInsert());
  }

  @override
  Future<int> createStudyWordIgnoreConflict(StudyWord studyWord) async {
    return db.insert(
      'study_words',
      studyWord.toMapForInsert(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> updateStudyWord(StudyWord studyWord) async {
    await db.update(
      'study_words',
      studyWord.toMap(),
      where: 'id = ?',
      whereArgs: [studyWord.id],
    );
  }
}

class _SqliteStudyLogRepository extends StudyLogRepository {
  _SqliteStudyLogRepository(this.db);

  final Database db;

  @override
  Future<int> insert(StudyLog log) async {
    return db.insert('study_logs', log.toMapForInsert());
  }

  @override
  Future<bool> existsFirstLearn({
    required int userId,
    required int wordId,
  }) async {
    final rows = await db.query(
      'study_logs',
      columns: ['id'],
      where: 'user_id = ? AND word_id = ? AND log_type = ?',
      whereArgs: [userId, wordId, LogType.firstLearn.value],
      limit: 1,
    );
    return rows.isNotEmpty;
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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('word SRS flow persists in sqlite', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());

    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT)');
    await db.execute('''
      CREATE TABLE words (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE study_words (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id          INTEGER NOT NULL,
          word_id          INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
          user_state       INTEGER DEFAULT 0 NOT NULL,
          next_review_at   INTEGER,
          last_reviewed_at INTEGER,
          streak           INTEGER DEFAULT 0,
          total_reviews    INTEGER DEFAULT 0,
          fail_count       INTEGER DEFAULT 0,
          interval         INTEGER DEFAULT 0,
          ease_factor      REAL DEFAULT 2.5,
          stability        REAL DEFAULT 0,
          difficulty       REAL DEFAULT 0,
          created_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
          updated_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
          UNIQUE (user_id, word_id)
      );
    ''');
    await db.execute('''
      CREATE TABLE study_logs (
          id                    INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id               INTEGER NOT NULL,
          word_id               INTEGER NOT NULL,
          question_type         TEXT,
          log_type              INTEGER NOT NULL,
          rating                INTEGER,
          algorithm             INTEGER DEFAULT 1,
          interval_after        REAL,
          next_review_at_after  INTEGER,
          ease_factor_after     REAL,
          fsrs_stability_after  REAL,
          fsrs_difficulty_after REAL,
          duration_ms           INTEGER DEFAULT 0,
          created_at            INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
      );
    ''');

    const userId = 1;
    const wordId = 101;
    await db.insert('users', {'id': userId});
    await db.insert('words', {'id': wordId, 'word': 'test'});

    final studyWordRepo = _SqliteStudyWordRepository(db);
    final studyLogRepo = _SqliteStudyLogRepository(db);
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
    expect(seen.interval, isNull);
    expect(seen.easeFactor, isNull);
    expect(dailyStats.learnedTotal, 0);

    await command.addWordToReview(userId, wordId);
    final learning = await studyWordRepo.getStudyWord(userId, wordId);
    expect(learning, isNotNull);
    expect(learning!.userState, LearningStatus.learning);
    expect(learning.nextReviewAt, isNotNull);
    expect(learning.interval, 1);
    expect(dailyStats.learnedTotal, 1);

    final firstLearnLogs = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM study_logs WHERE log_type = ?',
        [LogType.firstLearn.value],
      ),
    );
    expect(firstLearnLogs, 1);

    await command.onWordReviewed(
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
    );
    final afterFirstReview = await studyWordRepo.getStudyWord(userId, wordId);
    expect(afterFirstReview, isNotNull);
    expect(afterFirstReview!.totalReviews, 1);
    expect(afterFirstReview.interval, 1);
    expect(dailyStats.reviewedTotal, 1);

    await command.onWordReviewed(
      userId: userId,
      wordId: wordId,
      rating: ReviewRating.good,
    );
    final afterSecondReview = await studyWordRepo.getStudyWord(userId, wordId);
    expect(afterSecondReview, isNotNull);
    expect(afterSecondReview!.totalReviews, 2);
    expect(afterSecondReview.interval, 6);
    expect(dailyStats.reviewedTotal, 2);

    final reviewLogs = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM study_logs WHERE log_type = ?',
        [LogType.review.value],
      ),
    );
    expect(reviewLogs, 2);

    await command.markWordAsMastered(userId, wordId);
    final mastered = await studyWordRepo.getStudyWord(userId, wordId);
    expect(mastered, isNotNull);
    expect(mastered!.userState, LearningStatus.mastered);
  });
}
