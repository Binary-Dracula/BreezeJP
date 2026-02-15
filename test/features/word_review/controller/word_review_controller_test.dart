import 'package:breeze_jp/core/algorithm/algorithm_service.dart';
import 'package:breeze_jp/core/algorithm/algorithm_service_provider.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/db/app_database_provider.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_meaning.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_word_query.dart';
import 'package:breeze_jp/data/queries/word_read_queries.dart';
import 'package:breeze_jp/data/repositories/app_state_repository.dart';
import 'package:breeze_jp/data/repositories/app_state_repository_provider.dart';
import 'package:breeze_jp/data/repositories/daily_stat_repository.dart';
import 'package:breeze_jp/data/repositories/daily_stat_repository_provider.dart';
import 'package:breeze_jp/data/repositories/example_audio_repository.dart';
import 'package:breeze_jp/data/repositories/example_audio_repository_provider.dart';
import 'package:breeze_jp/data/repositories/example_repository.dart';
import 'package:breeze_jp/data/repositories/example_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_log_repository.dart';
import 'package:breeze_jp/data/repositories/study_log_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';
import 'package:breeze_jp/data/repositories/user_repository.dart';
import 'package:breeze_jp/data/repositories/user_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_audio_repository.dart';
import 'package:breeze_jp/data/repositories/word_audio_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_meaning_repository.dart';
import 'package:breeze_jp/data/repositories/word_meaning_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_repository.dart';
import 'package:breeze_jp/data/repositories/word_repository_provider.dart';
import 'package:breeze_jp/features/word_review/controller/word_review_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize ffi loader
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    final databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await _createSchema(db);
    await _seedData(db);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        wordRepositoryProvider.overrideWithValue(
          WordRepository(() async => db),
        ),
        wordMeaningRepositoryProvider.overrideWithValue(
          WordMeaningRepository(() async => db),
        ),
        studyWordRepositoryProvider.overrideWithValue(
          StudyWordRepository(() async => db),
        ),
        studyLogRepositoryProvider.overrideWithValue(
          StudyLogRepository(() async => db),
        ),
        userRepositoryProvider.overrideWithValue(
          UserRepository(() async => db),
        ),
        appStateRepositoryProvider.overrideWithValue(
          AppStateRepository(() async => db),
        ),
        // We need to override others to avoid them using AppDatabase.instance
        wordAudioRepositoryProvider.overrideWithValue(
          WordAudioRepository(() async => db),
        ),
        exampleRepositoryProvider.overrideWithValue(
          ExampleRepository(() async => db),
        ),
        exampleAudioRepositoryProvider.overrideWithValue(
          ExampleAudioRepository(() async => db),
        ),

        algorithmServiceProvider.overrideWithValue(AlgorithmService()),
        dailyStatRepositoryProvider.overrideWithValue(
          DailyStatRepository(() async => db),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'WordReviewController - Mistakes map to Again, Correct maps to Good, Item Re-queues',
    () async {
      // 1. Initialize Controller
      final controller = container.read(wordReviewControllerProvider.notifier);

      // 2. Load Review
      await controller.loadReview();

      // Verify state loaded
      var state = container.read(wordReviewControllerProvider);
      expect(state.activePairs.length, 2); // We seeded 2 due reviews

      // 3. Select Mistake for Word 1 (Cat)
      // Find pair for Cat
      final catPairIndex = state.activePairs.indexWhere(
        (p) => p.item.studyWord.wordId == 100,
      );
      final catRightIndex = state.rightOptions.indexWhere(
        (opt) => opt.pairIndex == catPairIndex,
      );

      // Pick correct left, but WRONG right
      final wrongRightIndex = (catRightIndex + 1) % state.rightOptions.length;

      await controller.selectLeft(catPairIndex);
      await controller.selectRight(wrongRightIndex);

      // Wait slightly
      await Future.delayed(const Duration(milliseconds: 100));

      // Now pick CORRECTLY for Cat
      await controller.selectLeft(catPairIndex);
      await controller.selectRight(catRightIndex);

      // 4. Verify Log: Should be Again (1)
      final logs = await db.query(
        'study_logs',
        where: 'word_id = 100 ORDER BY created_at DESC',
      );
      expect(logs.isNotEmpty, true);
      expect(logs.first['rating'], 1); // Again

      // 5. Verify Item Re-queued
      // Originally we had 2 items. We finished 1 (but with mistake).
      // It should have been added back to remainingItems.
      state = container.read(wordReviewControllerProvider);
      // Since we remove from active, add to remaining, then if active has space, fill from remaining.
      // Active pairs should still be full or refilled.
      // We expect the "Cat" item to be present in activePairs OR remainingItems.

      final catInActive = state.activePairs.any(
        (p) => p.item.studyWord.wordId == 100,
      );
      final catInRemaining = state.remainingItems.any(
        (i) => i.studyWord.wordId == 100,
      );

      expect(
        catInActive || catInRemaining,
        true,
        reason: "Item should be re-queued after mistake",
      );

      // 6. Test Good path for Word 2 (Dog)
      final dogPairIndex = state.activePairs.indexWhere(
        (p) => p.item.studyWord.wordId == 104,
      );
      // If dog moved, find it.
      if (dogPairIndex == -1) {
        // Dog might be in remaining if active size is small? No, seeded 2, limit ?
        // Assume dog is there.
      } else {
        final dogRightIndex = state.rightOptions.indexWhere(
          (opt) => opt.pairIndex == dogPairIndex,
        );
        await controller.selectLeft(dogPairIndex);
        await controller.selectRight(dogRightIndex);

        // Verify Log: Good (3)
        final dogLogs = await db.query(
          'study_logs',
          where: 'word_id = 104 ORDER BY created_at DESC',
        );
        expect(dogLogs.isNotEmpty, true);
        expect(dogLogs.first['rating'], 3); // Good

        // Verify Dog NOT re-queued
        state = container.read(wordReviewControllerProvider);
        final dogInActiveUnmatched = state.activePairs.any(
          (p) => p.item.studyWord.wordId == 104 && !p.isMatched,
        );
        final dogInRemaining = state.remainingItems.any(
          (i) => i.studyWord.wordId == 104,
        );
        expect(
          dogInActiveUnmatched || dogInRemaining,
          false,
          reason: "Correct item should not be re-queued",
        );
      }
    },
  );
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE words (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        word           TEXT NOT NULL,
        furigana       TEXT,
        romaji         TEXT,
        jlpt_level     TEXT,
        part_of_speech TEXT,
        pitch_accent   TEXT
    );
  ''');
  await db.execute('''
    CREATE TABLE word_meanings (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id          INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        meaning_cn       TEXT NOT NULL,
        definition_order INTEGER DEFAULT 1,
        notes            TEXT
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
        created_at            INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE users (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        username        TEXT UNIQUE NOT NULL,
        password_hash   TEXT NOT NULL,
        email           TEXT UNIQUE,
        nickname        TEXT,
        avatar_url      TEXT,
        status          INTEGER DEFAULT 1,
        settings        TEXT,
        locale          TEXT DEFAULT 'zh',
        timezone        TEXT,
        last_active_at  INTEGER,
        onboarding_completed INTEGER DEFAULT 0,
        pro_status      INTEGER DEFAULT 0,
        created_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
        updated_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE app_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        current_user_id INTEGER REFERENCES users(id)
    );
  ''');
  await db.execute('''
    CREATE TABLE daily_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        total_time_ms INTEGER DEFAULT 0,
        new_learned_count INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        unique_kana_reviewed_count INTEGER DEFAULT 0,
        rating_avg REAL DEFAULT 0,
        wrong_ratio REAL DEFAULT 0,
        new_interval_avg REAL DEFAULT 0,
        first_review_at INTEGER,
        last_review_at INTEGER,
        algorithm INTEGER DEFAULT 1,
        learning_quality_score INTEGER,
        UNIQUE(user_id, date)
    );
  ''');

  // Create dummy tables to avoid query errors
  await db.execute(
    'CREATE TABLE word_audio (id INTEGER PRIMARY KEY, word_id INTEGER, audio_filename TEXT, voice_type TEXT, source TEXT, audio_url TEXT);',
  );
  await db.execute(
    'CREATE TABLE example_sentences (id INTEGER PRIMARY KEY, word_id INTEGER, sentence_jp TEXT, sentence_furigana TEXT, translation_cn TEXT, notes TEXT);',
  );
  await db.execute(
    'CREATE TABLE example_audio (id INTEGER PRIMARY KEY, example_id INTEGER, audio_filename TEXT, voice_type TEXT, source TEXT, audio_url TEXT);',
  );
  await db.execute(
    'CREATE TABLE word_conjugations (id INTEGER PRIMARY KEY, word_id INTEGER, type_id INTEGER, conjugated_form TEXT, polite_form TEXT);',
  );
  await db.execute(
    'CREATE TABLE conjugation_types (id INTEGER PRIMARY KEY, name_ja TEXT, name_cn TEXT, sort_order INTEGER);',
  );
}

Future<void> _seedData(Database db) async {
  // User
  await db.insert('users', {
    'id': 1,
    'username': 'testuser',
    'password_hash': 'hash',
    'status': 1,
  });
  await db.insert('app_state', {'id': 1, 'current_user_id': 1});

  // Words
  await db.insert('words', {
    'id': 100,
    'word': '猫',
    'romaji': 'neko',
    'jlpt_level': 'N5',
  });
  await db.insert('word_meanings', {
    'word_id': 100,
    'meaning_cn': 'Cat',
    'definition_order': 1,
  });

  await db.insert('words', {
    'id': 104,
    'word': '犬',
    'romaji': 'inu',
    'jlpt_level': 'N5',
  });
  await db.insert('word_meanings', {
    'word_id': 104,
    'meaning_cn': 'Dog',
    'definition_order': 1,
  });

  // Study Words
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await db.insert('study_words', {
    'user_id': 1,
    'word_id': 100,
    'user_state': 1, // learning
    'next_review_at': now - 100, // Due
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('study_words', {
    'user_id': 1,
    'word_id': 104,
    'user_state': 1, // learning
    'next_review_at': now - 100, // Due
    'created_at': now,
    'updated_at': now,
  });
}
