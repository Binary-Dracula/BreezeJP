import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/data/commands/kana_command.dart';
import 'package:breeze_jp/data/commands/kana_command_provider.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/study_log.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';

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

  test('kana SRS flow: practice -> reviews -> mastered', () async {
    final repo = _InMemoryKanaRepository();
    final container = ProviderContainer(
      overrides: [kanaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final command = container.read(kanaCommandProvider);

    const userId = 1;
    const kanaId = 101;

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
    expect(afterFirstReview.nextReviewAt!, greaterThanOrEqualTo(firstNextReviewAt));

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
