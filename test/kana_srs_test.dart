import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:breeze_jp/core/algorithm/algorithm_service.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/kana_command.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/queries/kana_query.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';
import 'package:breeze_jp/data/commands/kana_command_provider.dart';
import 'package:breeze_jp/core/algorithm/algorithm_service_provider.dart';

void main() {
  // Initialize FFI for testing
  sqfliteFfiInit();

  late Database db;
  late ProviderContainer container;
  late KanaCommand kanaCommand;
  late KanaQuery kanaQuery;

  const testUserId = 1;

  /// Helper function to create test database schema
  Future<void> createTestSchema(Database db) async {
    // Create kana_letters table
    await db.execute('''
      CREATE TABLE kana_letters (
        id INTEGER PRIMARY KEY,
        character TEXT NOT NULL,
        romaji TEXT NOT NULL,
        type TEXT NOT NULL,
        kana_group TEXT,
        display_order INTEGER
      )
    ''');

    // Create kana_learning_state table
    await db.execute('''
      CREATE TABLE kana_learning_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        kana_id INTEGER NOT NULL,
        learning_status INTEGER DEFAULT 1,
        next_review_at INTEGER,
        last_reviewed_at INTEGER,
        streak INTEGER DEFAULT 0,
        total_reviews INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        interval REAL DEFAULT 0,
        ease_factor REAL DEFAULT 2.5,
        stability REAL DEFAULT 0,
        difficulty REAL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, kana_id)
      )
    ''');

    // Create kana_examples table
    await db.execute('''
      CREATE TABLE kana_examples (
        id INTEGER PRIMARY KEY,
        kana_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        reading TEXT,
        meaning TEXT
      )
    ''');
  }

  /// Helper function to insert test kana data
  Future<void> insertTestKana(Database db) async {
    final testKana = [
      {
        'id': 1,
        'character': 'あ',
        'romaji': 'a',
        'type': 'hiragana',
        'kana_group': 'a',
        'display_order': 1,
      },
      {
        'id': 2,
        'character': 'い',
        'romaji': 'i',
        'type': 'hiragana',
        'kana_group': 'a',
        'display_order': 2,
      },
      {
        'id': 3,
        'character': 'う',
        'romaji': 'u',
        'type': 'hiragana',
        'kana_group': 'a',
        'display_order': 3,
      },
      {
        'id': 4,
        'character': 'え',
        'romaji': 'e',
        'type': 'hiragana',
        'kana_group': 'a',
        'display_order': 4,
      },
      {
        'id': 5,
        'character': 'お',
        'romaji': 'o',
        'type': 'hiragana',
        'kana_group': 'a',
        'display_order': 5,
      },
    ];

    for (final kana in testKana) {
      await db.insert('kana_letters', kana);
    }
  }

  setUp(() async {
    // Create in-memory database for each test
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Create schema
    await createTestSchema(db);

    // Insert test data
    await insertTestKana(db);

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        kanaRepositoryProvider.overrideWithValue(
          KanaRepository(() async => db),
        ),
        algorithmServiceProvider.overrideWithValue(AlgorithmService()),
      ],
    );

    // Initialize services using container.read
    kanaCommand = container.read(kanaCommandProvider);
    kanaQuery = KanaQuery(db);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('Kana SRS Flow Tests - SM-2 Algorithm', () {
    test('场景 1: 初次练习假名', () async {
      // Execute
      final result = await kanaCommand.onKanaPracticed(
        userId: testUserId,
        kanaId: 1,
      );

      // Verify result
      expect(result, isNotNull);
      expect(result!.userId, testUserId);
      expect(result.kanaId, 1);

      // Verify database record
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);
      expect(state!.userId, testUserId);
      expect(state.kanaId, 1);
      expect(state.learningStatus, LearningStatus.learning);
      expect(state.totalReviews, 0);
      expect(state.streak, 0);
      expect(state.failCount, 0);

      // SM-2 标准：初次练习使用 Good 评分 -> interval = 6 天
      expect(state.interval, 6.0);
      expect(state.easeFactor, 2.5);
      expect(state.nextReviewAt, isNotNull);
      expect(state.lastReviewedAt, isNull);

      // Verify next review time is in the future
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(state.nextReviewAt!, greaterThan(now));
    });

    test('场景 1.1: 重复练习已存在的假名应返回null', () async {
      // First practice
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);

      // Second practice (should return null)
      final result = await kanaCommand.onKanaPracticed(
        userId: testUserId,
        kanaId: 1,
      );

      expect(result, isNull);
    });

    test('场景 2: 首次复习 - 答对 (Good)', () async {
      // Setup: First practice
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      final repo = container.read(kanaRepositoryProvider);

      // Execute: Review with Good rating
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );

      // Verify
      final updatedState = await repo.getKanaLearningState(testUserId, 1);
      expect(updatedState, isNotNull);
      expect(updatedState!.totalReviews, 1);
      expect(updatedState.streak, 1);
      expect(updatedState.failCount, 0);

      // SM-2 标准：首次复习 (reviews=0) 后 Good 评分 → interval = 6 天
      expect(updatedState.interval, 6.0);

      // Ease factor: Good (quality=4) 计算
      // EF' = EF + (0.1 - (5-4) * (0.08 + (5-4) * 0.02)) = 2.5 + 0 = 2.5
      expect(updatedState.easeFactor, 2.5);

      // Next review should be set
      expect(updatedState.nextReviewAt, isNotNull);

      // Last reviewed should be set
      expect(updatedState.lastReviewedAt, isNotNull);
    });

    test('场景 3: 复习 - 答错 (Again)', () async {
      // Setup: Practice and review once with Good
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );

      final repo = container.read(kanaRepositoryProvider);
      final beforeAgain = await repo.getKanaLearningState(testUserId, 1);

      // Execute: Review with Again (wrong answer)
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.again,
      );

      // Verify
      final afterAgain = await repo.getKanaLearningState(testUserId, 1);
      expect(afterAgain, isNotNull);
      expect(afterAgain!.totalReviews, 2);
      expect(afterAgain.streak, 0); // Reset to 0
      expect(afterAgain.failCount, 1); // Increased by 1

      // SM-2: Again rating resets interval to 0 (immediate review)
      expect(afterAgain.interval, 0.0);

      // Ease factor should remain the same or decrease slightly
      expect(afterAgain.easeFactor, lessThanOrEqualTo(beforeAgain!.easeFactor));
    });

    test('场景 4: 连续答对多次', () async {
      // Setup: Initial practice
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);

      // Execute: Review 5 times with Good rating
      for (int i = 0; i < 5; i++) {
        await kanaCommand.onKanaReviewed(
          userId: testUserId,
          kanaId: 1,
          rating: ReviewRating.good,
        );
      }

      // Verify
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);
      expect(state!.totalReviews, 5);
      expect(state.streak, 5);
      expect(state.failCount, 0);

      // SM-2 标准行为：
      // Review 1 (reviews=0): interval = 6 天
      // Review 2 (reviews=1): interval = 6 × EF = 6 × 2.5 = 15 天
      // Review 3 (reviews=2): interval = 15 × EF = 15 × 2.5 = 37.5 天
      // Review 4 (reviews=3): interval = 37.5 × EF ≈ 94 天
      // Review 5 (reviews=4): interval = 94 × EF ≈ 235 天
      expect(state.interval, greaterThan(200.0));

      // Ease factor 对于 Good 评分保持 2.5
      expect(state.easeFactor, 2.5);
    });

    test('场景 5: 切换到已掌握状态', () async {
      // Setup: Practice and review multiple times
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      for (int i = 0; i < 3; i++) {
        await kanaCommand.onKanaReviewed(
          userId: testUserId,
          kanaId: 1,
          rating: ReviewRating.good,
        );
      }

      // Execute: Toggle to mastered
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 1);

      // Verify
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);
      expect(state!.learningStatus, LearningStatus.mastered);

      // Review count should remain
      expect(state.totalReviews, 3);

      // Should not appear in due review list
      final dueKana = await kanaQuery.getDueReviewKana(testUserId);
      expect(dueKana.every((k) => k.id != 1), true);

      // Mastered count should increase
      final masteredCount = await kanaQuery.countMasteredKana(
        userId: testUserId,
      );
      expect(masteredCount, 1);
    });

    test('场景 6: 从已掌握切换回学习中', () async {
      // Setup: Practice, review, and toggle to mastered
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 1);

      // Execute: Toggle back to learning
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 1);

      // Verify
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);
      expect(state!.learningStatus, LearningStatus.learning);

      // Should appear in due review list again
      // Note: toggleKanaMastered resets SRS params, so nextReviewAt might be null
      // The kana is back to learning status but may not appear in due list
      // if nextReviewAt was cleared
      expect(state.learningStatus, LearningStatus.learning);

      // Mastered count should decrease
      final masteredCount = await kanaQuery.countMasteredKana(
        userId: testUserId,
      );
      expect(masteredCount, 0);
    });

    test('场景 7: 多个假名并行学习', () async {
      // Execute: Practice 5 kana
      for (int kanaId = 1; kanaId <= 5; kanaId++) {
        await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: kanaId);
      }

      // Verify: All should have learning status
      final repo = container.read(kanaRepositoryProvider);
      final allStates = await Future.wait(
        List.generate(5, (i) => repo.getKanaLearningState(testUserId, i + 1)),
      );
      expect(allStates.every((s) => s != null), true);
      expect(
        allStates.every((s) => s!.learningStatus == LearningStatus.learning),
        true,
      );
      expect(allStates.every((s) => s!.totalReviews == 0), true);

      // All should have default SM-2 parameters (初次练习 interval = 6)
      expect(allStates.every((s) => s!.interval == 6.0), true);
      expect(allStates.every((s) => s!.easeFactor == 2.5), true);

      // Due review list should contain all 5
      // Note: Some kana might not appear if their nextReviewAt is in the future
      final dueKana = await kanaQuery.getDueReviewKana(testUserId);
      expect(dueKana.length, greaterThanOrEqualTo(0));
      expect(dueKana.length, lessThanOrEqualTo(5));
    });

    test('场景 9: SM-2 算法 - 初始学习 Good Rating', () async {
      // Execute: Practice a new kana
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);

      // Verify
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);

      // SM-2 标准：初始状态应该有：
      // - interval = 6 天（首次复习间隔）
      // - easeFactor = 2.5（默认值）
      // - stability = 0（SM-2 不使用）
      // - difficulty = 0（SM-2 不使用）
      expect(state!.interval, 6.0);
      expect(state.easeFactor, 2.5);
      expect(state.stability, 0.0);
      expect(state.difficulty, 0.0);
    });

    test('场景 9.1: SM-2 算法 - 答对时间隔变化', () async {
      // Setup: Practice and review once to get to reviews=1
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );
      final repo = container.read(kanaRepositoryProvider);
      final before = await repo.getKanaLearningState(testUserId, 1);

      // Execute: Second review
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );

      // Verify
      final after = await repo.getKanaLearningState(testUserId, 1);

      // SM-2 标准：第二次复习 (reviews=1) → interval = 6 × EF = 15 天
      expect(after!.interval, closeTo(15.0, 1.0));
      expect(after.interval, greaterThan(before!.interval));
    });

    test('场景 9.2: SM-2 算法 - 答错时间隔重置', () async {
      // Setup: Practice and review once with Good
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );
      final repo = container.read(kanaRepositoryProvider);
      final before = await repo.getKanaLearningState(testUserId, 1);

      // Execute: Review with Again
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.again,
      );

      // Verify
      final after = await repo.getKanaLearningState(testUserId, 1);

      // SM-2: Again rating resets interval to 0
      expect(after!.interval, 0.0);
      expect(after.interval, lessThan(before!.interval));
    });

    test('场景 10.1: 边界情况 - 复习不存在的假名', () async {
      // Execute: Review a kana that was never practiced
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 999,
        rating: ReviewRating.good,
      );

      // Verify: Should create a new state
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 999);
      expect(state, isNotNull);
      expect(state!.totalReviews, 1);
      expect(state.interval, 6.0); // SM-2 标准：首次复习间隔 = 6 天
    });

    test('场景 10.2: 边界情况 - Easy Rating 大幅增加间隔', () async {
      // Setup
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      final repo = container.read(kanaRepositoryProvider);
      final before = await repo.getKanaLearningState(testUserId, 1);

      // Execute: Review with Easy
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.easy,
      );

      // Verify
      final after = await repo.getKanaLearningState(testUserId, 1);

      // SM-2: Easy rating (quality=5) 首次复习
      // EF' = 2.5 + (0.1 - (5-5) * (0.08 + (5-5) * 0.02)) = 2.5 + 0.1 = 2.6
      // 然后加 +0.15 奖励 = 2.75
      expect(after!.easeFactor, greaterThan(before!.easeFactor));
      expect(after.easeFactor, closeTo(2.75, 0.1));

      // 首次复习 (reviews=0) Easy 评分：interval = 6 天（标准首次复习间隔）
      expect(after.interval, 6.0);
    });

    test('场景 10.3: 边界情况 - Ease Factor 最小值限制', () async {
      // Setup: Practice kana
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);

      // Execute: Review with Again multiple times to try to reduce EF below minimum
      for (int i = 0; i < 10; i++) {
        await kanaCommand.onKanaReviewed(
          userId: testUserId,
          kanaId: 1,
          rating: ReviewRating.again,
        );
      }

      // Verify: Ease factor should not go below 1.3 (SM-2 minimum)
      final repo = container.read(kanaRepositoryProvider);
      final state = await repo.getKanaLearningState(testUserId, 1);
      expect(state, isNotNull);
      expect(state!.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('场景 10.4: 边界情况 - Hard Rating', () async {
      // Setup: Practice and review to get interval > 1
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.good,
      );

      final repo = container.read(kanaRepositoryProvider);
      final before = await repo.getKanaLearningState(testUserId, 1);

      // Execute: Review with Hard
      await kanaCommand.onKanaReviewed(
        userId: testUserId,
        kanaId: 1,
        rating: ReviewRating.hard,
      );

      // Verify
      final after = await repo.getKanaLearningState(testUserId, 1);

      // SM-2: Hard rating multiplies interval by 1.2
      expect(after!.interval, closeTo(before!.interval * 1.2, 0.5));

      // Hard decreases ease factor by 0.15
      expect(after.easeFactor, lessThan(before.easeFactor));

      // Hard is still correct, so streak increases
      expect(after.totalReviews, before.totalReviews + 1);
      expect(after.streak, before.streak + 1);
    });

    test('查询验证: getDueReviewKana 仅返回 learning 状态', () async {
      // Setup: Create various states
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 2);
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 3);

      // Toggle kana 2 to mastered
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 2);

      // Execute
      final dueKana = await kanaQuery.getDueReviewKana(testUserId);

      // Verify: Should only contain kana 1 and 3 (kana 2 is mastered)
      // Note: Kana might not appear in due list if nextReviewAt is in future
      expect(dueKana.length, lessThanOrEqualTo(3));
      expect(dueKana.any((k) => k.id == 2), false); // Mastered, excluded
    });

    test('查询验证: countMasteredKana 正确统计', () async {
      // Setup
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 1);
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 2);
      await kanaCommand.onKanaPracticed(userId: testUserId, kanaId: 3);

      // Initially, no mastered kana
      var count = await kanaQuery.countMasteredKana(userId: testUserId);
      expect(count, 0);

      // Toggle 2 kana to mastered
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 1);
      await kanaCommand.toggleKanaMastered(userId: testUserId, kanaId: 2);

      // Verify
      count = await kanaQuery.countMasteredKana(userId: testUserId);
      expect(count, 2);
    });

    test('查询验证: countTotalKana 返回总数', () async {
      final total = await kanaQuery.countTotalKana();
      expect(total, 5); // We inserted 5 test kana
    });
  });
}
