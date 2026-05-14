import 'package:breeze_jp/core/algorithm/srs_types.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/review_session_remote_command.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/kana_letter.dart';
import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository_provider.dart';
import 'package:breeze_jp/features/kana/review/controller/kana_review_controller.dart';
import 'package:breeze_jp/features/kana/review/state/kana_review_state.dart';
import 'package:breeze_jp/features/kana/review/state/review_kana_item.dart';
import 'package:breeze_jp/features/review/shared/review_session_codec.dart';
import 'package:breeze_jp/features/word_review/state/word_review_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockStudyRemoteQuery extends Mock implements StudyRemoteQuery {}

class _MockReviewSessionRemoteCommand extends Mock
    implements ReviewSessionRemoteCommand {}

class _MockLearningSessionRepository extends Mock
    implements LearningSessionRepository {}

void main() {
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockStudyRemoteQuery studyRemoteQuery;
  late _MockReviewSessionRemoteCommand reviewSessionRemoteCommand;
  late _MockLearningSessionRepository sessionRepository;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        studyRemoteQueryProvider.overrideWith((ref) => studyRemoteQuery),
        reviewSessionRemoteCommandProvider.overrideWith(
          (ref) => reviewSessionRemoteCommand,
        ),
        learningSessionRepositoryProvider.overrideWith(
          (ref) => sessionRepository,
        ),
      ],
    );
  }

  setUpAll(() {
    registerFallbackValue(
      LearningSession.kanaReview(
        id: 'fallback-kana-review-session',
        userId: 1,
        serverSessionId: 'remote-session',
        dataPayload: '{}',
        createdAt: DateTime.utc(2026, 4, 20),
      ),
    );
    registerFallbackValue(<KanaReviewAnsweredResult>[]);
  });

  setUp(() async {
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    studyRemoteQuery = _MockStudyRemoteQuery();
    reviewSessionRemoteCommand = _MockReviewSessionRemoteCommand();
    sessionRepository = _MockLearningSessionRepository();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(
      () => studyRemoteQuery.createKanaReviewSession(localUserId: 1, limit: 20),
    ).thenAnswer((_) async => _remoteKanaSession(user.id));
    when(
      () => sessionRepository.getActiveSessionByType(
        1,
        LearningSessionType.kanaReview,
      ),
    ).thenAnswer((_) async => null);
    when(
      () => reviewSessionRemoteCommand.completeKanaSession(
        sessionId: any(named: 'sessionId'),
        results: any(named: 'results'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => sessionRepository.createSession(any()),
    ).thenAnswer((_) async => 'local-session-1');
    when(() => sessionRepository.updateSession(any())).thenAnswer((_) async {});
    when(() => sessionRepository.deleteSession(any())).thenAnswer((_) async {});
  });

  test(
    'loads remote kana review session and completes via local snapshot flow',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(kanaReviewControllerProvider.notifier);
      await notifier.loadReview();

      final loaded = container.read(kanaReviewControllerProvider);
      expect(loaded.localSessionId, 'local-session-1');
      expect(loaded.sessionId, 'kana-session-1');
      expect(loaded.currentPhase, ReviewCardPhase.testing);

      final correctAnswer = _correctOptionFor(loaded.currentItem!);
      await notifier.submitObjectiveAnswer(correctAnswer);
      expect(
        container.read(kanaReviewControllerProvider).currentPhase,
        ReviewCardPhase.grading,
      );

      await notifier.submitSubjectiveRating(ReviewRating.good);

      final finished = container.read(kanaReviewControllerProvider);
      expect(finished.isAllFinished, isTrue);
      expect(finished.sessionId, isNull);
      verify(
        () =>
            studyRemoteQuery.createKanaReviewSession(localUserId: 1, limit: 20),
      ).called(1);
      verify(() => sessionRepository.updateSession(any())).called(1);
      verify(
        () => reviewSessionRemoteCommand.completeKanaSession(
          sessionId: 'kana-session-1',
          results: any(named: 'results'),
        ),
      ).called(1);
    },
  );

  test(
    'resumes local kana review session without creating remote session',
    () async {
      final item = _kanaReviewItem(user.id);
      when(
        () => sessionRepository.getActiveSessionByType(
          1,
          LearningSessionType.kanaReview,
        ),
      ).thenAnswer(
        (_) async => LearningSession.kanaReview(
          id: 'local-kana-review-2',
          userId: 1,
          serverSessionId: 'remote-kana-review-2',
          dataPayload: encodeKanaReviewSessionPayload(
            initialItems: [item],
            dynamicQueue: [item],
            answeredResults: const [],
            currentIndex: 0,
          ),
          createdAt: DateTime.now(),
        ),
      );

      final container = buildContainer();
      addTearDown(container.dispose);

      await container.read(kanaReviewControllerProvider.notifier).loadReview();

      final loaded = container.read(kanaReviewControllerProvider);
      expect(loaded.localSessionId, 'local-kana-review-2');
      expect(loaded.sessionId, 'remote-kana-review-2');
      expect(loaded.currentItem?.kanaLetter.id, 1);
      verifyNever(
        () =>
            studyRemoteQuery.createKanaReviewSession(localUserId: 1, limit: 20),
      );
    },
  );

  test('marks review as empty when remote session has no items', () async {
    when(
      () => studyRemoteQuery.createKanaReviewSession(localUserId: 1, limit: 20),
    ).thenAnswer((_) async => const RemoteKanaReviewSession.empty());

    final container = buildContainer();
    addTearDown(container.dispose);

    final notifier = container.read(kanaReviewControllerProvider.notifier);
    await notifier.loadReview();

    final loaded = container.read(kanaReviewControllerProvider);
    expect(loaded.isEmpty, isTrue);
    expect(loaded.items, isEmpty);
    expect(loaded.error, isNull);
  });
}

ReviewKanaItem _kanaReviewItem(int userId) {
  return ReviewKanaItem(
    kanaLetter: KanaLetter(
      id: 1,
      kanaChar: 'あ',
      scriptKind: KanaScriptKind.hiragana,
      romaji: 'a',
      vowel: 'a',
      pairGroupId: 100,
      displayOrder: 1,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
    learningState: KanaLearningState(
      id: 0,
      userId: userId,
      kanaId: 1,
      nextReviewAt: 1713571200,
      createdAt: 1713571200,
      updatedAt: 1713571200,
    ),
    audioFilename: null,
    questionType: ReviewQuestionType.hiraganaToRomaji,
    options: const ['a', 'i', 'u', 'e'],
    counterpartLetter: KanaLetter(
      id: 2,
      kanaChar: 'ア',
      scriptKind: KanaScriptKind.katakana,
      romaji: 'a',
      vowel: 'a',
      pairGroupId: 100,
      displayOrder: 2,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
  );
}

RemoteKanaReviewSession _remoteKanaSession(int userId) {
  final item = _kanaReviewItem(userId);
  return RemoteKanaReviewSession(
    sessionId: 'kana-session-1',
    currentIndex: 0,
    items: [
      RemoteKanaReviewSessionItem(
        kanaLetter: item.kanaLetter,
        learningState: item.learningState,
        questionType: 'hiragana_to_romaji',
        options: item.options,
        audioFilename: item.audioFilename,
        counterpartLetter: item.counterpartLetter,
      ),
    ],
  );
}

String _correctOptionFor(ReviewKanaItem item) {
  switch (item.questionType) {
    case ReviewQuestionType.hiraganaToRomaji:
    case ReviewQuestionType.katakanaToRomaji:
      return item.kanaLetter.romaji;
    case ReviewQuestionType.romajiToHiragana:
    case ReviewQuestionType.romajiToKatakana:
      return item.kanaLetter.kanaChar;
    case ReviewQuestionType.hiraganaToKatakana:
    case ReviewQuestionType.katakanaToHiragana:
      return item.counterpartLetter?.kanaChar ?? item.kanaLetter.kanaChar;
  }
}
