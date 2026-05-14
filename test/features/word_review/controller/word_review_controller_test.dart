import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/features/review/shared/review_session_codec.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/review_session_remote_command.dart';
import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_detail.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository_provider.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/features/word_review/controller/word_review_controller.dart';
import 'package:breeze_jp/features/word_review/state/word_review_item.dart';
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
  late _MockStudyRemoteQuery remoteQuery;
  late _MockReviewSessionRemoteCommand reviewSessionRemoteCommand;
  late _MockLearningSessionRepository sessionRepository;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        studyRemoteQueryProvider.overrideWith((ref) => remoteQuery),
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
      LearningSession.wordReview(
        id: 'fallback-review-session',
        userId: 1,
        serverSessionId: 'remote-session',
        dataPayload: '{}',
        createdAt: DateTime.utc(2026, 4, 20),
      ),
    );
    registerFallbackValue(<WordReviewAnsweredResult>[]);
  });

  setUp(() async {
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    remoteQuery = _MockStudyRemoteQuery();
    reviewSessionRemoteCommand = _MockReviewSessionRemoteCommand();
    sessionRepository = _MockLearningSessionRepository();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(
      () => remoteQuery.createWordReviewSession(localUserId: 1, limit: 20),
    ).thenAnswer((_) async => _remoteWordSession(user.id));
    when(
      () => sessionRepository.getActiveSessionByType(
        1,
        LearningSessionType.wordReview,
      ),
    ).thenAnswer((_) async => null);
    when(
      () => reviewSessionRemoteCommand.completeWordSession(
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
    'loads remote word review session and completes via local snapshot flow',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(wordReviewControllerProvider.notifier);
      await notifier.loadReview();

      final loaded = container.read(wordReviewControllerProvider);
      expect(loaded.localSessionId, 'local-session-1');
      expect(loaded.sessionId, 'word-session-1');
      expect(loaded.currentPhase, ReviewCardPhase.testing);

      await notifier.submitObjectiveAnswer('词语');
      expect(
        container.read(wordReviewControllerProvider).currentPhase,
        ReviewCardPhase.grading,
      );

      await notifier.continueToNext();

      final finished = container.read(wordReviewControllerProvider);
      expect(finished.isAllFinished, isTrue);
      expect(finished.sessionId, isNull);
      verify(
        () => remoteQuery.createWordReviewSession(localUserId: 1, limit: 20),
      ).called(1);
      verify(() => sessionRepository.updateSession(any())).called(1);
      verify(
        () => reviewSessionRemoteCommand.completeWordSession(
          sessionId: 'word-session-1',
          results: any(named: 'results'),
        ),
      ).called(1);
    },
  );

  test(
    'resumes local word review session without creating remote session',
    () async {
      final item = _wordReviewItem(user.id);
      when(
        () => sessionRepository.getActiveSessionByType(
          1,
          LearningSessionType.wordReview,
        ),
      ).thenAnswer(
        (_) async => LearningSession.wordReview(
          id: 'local-review-2',
          userId: 1,
          serverSessionId: 'remote-review-2',
          dataPayload: encodeWordReviewSessionPayload(
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

      await container.read(wordReviewControllerProvider.notifier).loadReview();

      final loaded = container.read(wordReviewControllerProvider);
      expect(loaded.localSessionId, 'local-review-2');
      expect(loaded.sessionId, 'remote-review-2');
      expect(loaded.currentItem?.studyWord.wordId, 'word-1');
      verifyNever(
        () => remoteQuery.createWordReviewSession(localUserId: 1, limit: 20),
      );
    },
  );

  test('marks review as empty when remote session has no items', () async {
    when(
      () => remoteQuery.createWordReviewSession(localUserId: 1, limit: 20),
    ).thenAnswer((_) async => const RemoteWordReviewSession.empty());

    final container = buildContainer();
    addTearDown(container.dispose);

    final notifier = container.read(wordReviewControllerProvider.notifier);
    await notifier.loadReview();

    final loaded = container.read(wordReviewControllerProvider);
    expect(loaded.isEmpty, isTrue);
    expect(loaded.items, isEmpty);
    expect(loaded.error, isNull);
  });
}

WordReviewItem _wordReviewItem(int userId) {
  return WordReviewItem(
    studyWord: StudyWord(
      id: 1,
      userId: userId,
      wordId: 'word-1',
      bookId: 'book-1',
      userState: LearningStatus.learning,
      createdAt: DateTime.utc(2026, 4, 20),
      updatedAt: DateTime.utc(2026, 4, 20),
    ),
    wordDetail: WordDetail(
      word: Word(
        id: 'word-1',
        word: '言葉',
        reading: 'ことば',
        partOfSpeech: 'noun',
        primaryMeaning: '词语',
      ),
      richContent: WordRichContent.empty(),
      examples: const [],
    ),
    questionType: WordReviewQuestionType.wordToMeaning,
    audioSource: null,
    meaning: '词语',
    reading: 'ことば',
    options: const ['词语', '句子', '语法', '文章'],
  );
}

RemoteWordReviewSession _remoteWordSession(int userId) {
  return RemoteWordReviewSession(
    sessionId: 'word-session-1',
    currentIndex: 0,
    items: [
      RemoteWordReviewSessionItem(
        studyWord: StudyWord(
          id: 1,
          userId: userId,
          wordId: 'word-1',
          bookId: 'book-1',
          userState: LearningStatus.learning,
          createdAt: DateTime.utc(2026, 4, 20),
          updatedAt: DateTime.utc(2026, 4, 20),
        ),
        wordDetail: WordDetail(
          word: Word(
            id: 'word-1',
            word: '言葉',
            reading: 'ことば',
            partOfSpeech: 'noun',
            primaryMeaning: '词语',
          ),
          richContent: WordRichContent.empty(),
          examples: const [],
        ),
        questionType: 'word_to_meaning',
        audioSource: null,
        meaning: '词语',
        reading: 'ことば',
        options: const ['词语', '句子', '语法', '文章'],
      ),
    ],
  );
}
