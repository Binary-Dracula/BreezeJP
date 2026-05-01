import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/review_session_remote_command.dart';
import 'package:breeze_jp/data/commands/word_command.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_detail.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/features/word_review/controller/word_review_controller.dart';
import 'package:breeze_jp/features/word_review/state/word_review_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockStudyRemoteQuery extends Mock implements StudyRemoteQuery {}

class _MockReviewSessionRemoteCommand extends Mock
    implements ReviewSessionRemoteCommand {}

class _MockWordCommand extends Mock implements WordCommand {}

void main() {
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockStudyRemoteQuery remoteQuery;
  late _MockReviewSessionRemoteCommand reviewSessionRemoteCommand;
  late _MockWordCommand wordCommand;

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
        wordCommandProvider.overrideWith((ref) => wordCommand),
      ],
    );
  }

  setUp(() async {
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    remoteQuery = _MockStudyRemoteQuery();
    reviewSessionRemoteCommand = _MockReviewSessionRemoteCommand();
    wordCommand = _MockWordCommand();

    registerFallbackValue(const WordReviewState());

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(
      () => remoteQuery.fetchWordReviewSession(localUserId: 1, limit: 20),
    ).thenAnswer((_) async => _remoteWordSession(user.id));
    when(
      () => reviewSessionRemoteCommand.saveWordSession(
        sessionId: any(named: 'sessionId'),
        state: any(named: 'state'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => reviewSessionRemoteCommand.completeWordSession(
        sessionId: any(named: 'sessionId'),
        state: any(named: 'state'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'loads remote word review session with session id and checkpoints progress',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(wordReviewControllerProvider.notifier);
      await notifier.loadReview();

      final loaded = container.read(wordReviewControllerProvider);
      expect(loaded.sessionId, 'word-session-1');
      expect(loaded.currentPhase, ReviewCardPhase.testing);

      await notifier.submitObjectiveAnswer('词语');

      final resumed = container.read(wordReviewControllerProvider);
      expect(resumed.currentPhase, ReviewCardPhase.grading);
      expect(resumed.currentItem?.studyWord.wordId, 'word-1');
      verify(
        () => remoteQuery.fetchWordReviewSession(localUserId: 1, limit: 20),
      ).called(1);
      verify(
        () => reviewSessionRemoteCommand.saveWordSession(
          sessionId: 'word-session-1',
          state: any(named: 'state'),
        ),
      ).called(1);
    },
  );

  test('marks review as empty when remote session has no items', () async {
    when(
      () => remoteQuery.fetchWordReviewSession(localUserId: 1, limit: 20),
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

RemoteWordReviewSession _remoteWordSession(int userId) {
  return RemoteWordReviewSession(
    sessionId: 'word-session-1',
    currentIndex: 0,
    currentPhase: 'testing',
    hasMistakeOnCurrent: false,
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
