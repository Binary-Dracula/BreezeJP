import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:breeze_jp/data/commands/kana_command_provider.dart';
import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';

void main() {
  setUpAll(() {
    logger.setTestMode(true);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('kana SRS flow persists in sqlite', () async {
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());

    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT)');
    await db.execute(
      'CREATE TABLE kana_letters (id INTEGER PRIMARY KEY AUTOINCREMENT)',
    );
    await db.execute('''
      CREATE TABLE kana_learning_state (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id          INTEGER NOT NULL REFERENCES users(id),
          kana_id          INTEGER NOT NULL REFERENCES kana_letters(id),
          learning_status  INTEGER DEFAULT 0 NOT NULL,
          next_review_at   INTEGER,
          last_reviewed_at INTEGER,
          streak           INTEGER DEFAULT 0,
          total_reviews    INTEGER DEFAULT 0,
          fail_count       INTEGER DEFAULT 0,
          interval         REAL DEFAULT 0,
          ease_factor      REAL DEFAULT 2.5,
          stability        REAL DEFAULT 0,
          difficulty       REAL DEFAULT 0,
          created_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
          updated_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
          UNIQUE (user_id, kana_id)
      );
    ''');

    const userId = 1;
    const kanaId = 101;
    await db.insert('users', {'id': userId});
    await db.insert('kana_letters', {'id': kanaId});

    final repo = KanaRepository(() async => db);
    final container = ProviderContainer(
      overrides: [kanaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final command = container.read(kanaCommandProvider);

    await command.onKanaPracticed(userId: userId, kanaId: kanaId);
    final initial = await repo.getKanaLearningState(userId, kanaId);
    expect(initial, isNotNull);
    expect(initial!.learningStatus, LearningStatus.learning);
    expect(initial.interval, closeTo(1.0, 0.001));
    expect(initial.easeFactor, closeTo(2.5, 0.001));
    expect(initial.stability, closeTo(0.0, 0.001));
    expect(initial.difficulty, closeTo(0.0, 0.001));
    expect(initial.totalReviews, 0);
    expect(initial.streak, 0);
    expect(initial.failCount, 0);
    expect(initial.nextReviewAt, isNotNull);
    final firstNextReviewAt = initial.nextReviewAt!;

    await command.onKanaReviewed(
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.good,
    );
    final afterFirstReview = await repo.getKanaLearningState(userId, kanaId);
    expect(afterFirstReview, isNotNull);
    expect(afterFirstReview!.totalReviews, 1);
    expect(afterFirstReview.streak, 1);
    expect(afterFirstReview.failCount, 0);
    expect(afterFirstReview.interval, closeTo(1.0, 0.001));
    expect(afterFirstReview.nextReviewAt, isNotNull);
    expect(
      afterFirstReview.nextReviewAt!,
      greaterThanOrEqualTo(firstNextReviewAt),
    );

    await command.onKanaReviewed(
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.good,
    );
    final afterSecondReview = await repo.getKanaLearningState(userId, kanaId);
    expect(afterSecondReview, isNotNull);
    expect(afterSecondReview!.totalReviews, 2);
    expect(afterSecondReview.streak, 2);
    expect(afterSecondReview.failCount, 0);
    expect(afterSecondReview.interval, closeTo(6.0, 0.001));
    expect(
      afterSecondReview.nextReviewAt,
      greaterThan(afterFirstReview.nextReviewAt!),
    );

    await command.onKanaReviewed(
      userId: userId,
      kanaId: kanaId,
      rating: ReviewRating.good,
    );
    final afterThirdReview = await repo.getKanaLearningState(userId, kanaId);
    expect(afterThirdReview, isNotNull);
    expect(afterThirdReview!.totalReviews, 3);
    expect(afterThirdReview.streak, 3);
    expect(afterThirdReview.failCount, 0);
    expect(afterThirdReview.interval, closeTo(15.0, 0.001));
    expect(
      afterThirdReview.nextReviewAt,
      greaterThan(afterSecondReview.nextReviewAt!),
    );

    await command.toggleKanaMastered(userId: userId, kanaId: kanaId);
    final mastered = await repo.getKanaLearningState(userId, kanaId);
    expect(mastered, isNotNull);
    expect(mastered!.learningStatus, LearningStatus.mastered);
  });
}
