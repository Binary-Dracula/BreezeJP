import 'package:breeze_jp/core/providers/preferences_provider.dart';
import 'package:dio/dio.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/vocab_remote_query.dart';
import 'package:breeze_jp/data/queries/vocab_remote_query_provider.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository_provider.dart';
import 'package:breeze_jp/features/learn/controller/learn_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockLearningSessionRepository extends Mock
    implements LearningSessionRepository {}

class _MockVocabRemoteQuery extends Mock implements VocabRemoteQuery {}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockLearningSessionRepository sessionRepository;
  late _MockVocabRemoteQuery remoteQuery;

  final user = User(id: 1, username: 'u', passwordHash: 'p');
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(
      LearningSession.wordLearn(
        id: 'fallback-session',
        userId: 1,
        serverSessionId: 'remote-fallback',
        bookId: 'book-1',
        wordsPayload: '[]',
        currentIndex: 0,
        batchStartSort: 0,
        batchEndSort: 0,
        createdAt: DateTime.utc(2026, 5, 13),
      ),
    );
    registerFallbackValue(<LearnWordStateResult>[]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_book_id': 'book-1'});
    prefs = await SharedPreferences.getInstance();
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    sessionRepository = _MockLearningSessionRepository();
    remoteQuery = _MockVocabRemoteQuery();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(() => sessionRepository.deleteSession(any())).thenAnswer((_) async {});
    when(() => sessionRepository.updateSession(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        learningSessionRepositoryProvider.overrideWith(
          (ref) => sessionRepository,
        ),
        vocabRemoteQueryProvider.overrideWith((ref) => remoteQuery),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'blocks next batch when remote learn session returns book unavailable',
    () async {
      when(
        () => sessionRepository.getActiveSession(1, 'book-1'),
      ).thenAnswer((_) async => null);
      when(
        () => remoteQuery.createLearnSession(bookId: 'book-1', limit: 10),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/learn/sessions'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/learn/sessions'),
            statusCode: 409,
            data: {
              'error': {'code': 'BOOK_UNAVAILABLE'},
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await container
          .read(learnControllerProvider.notifier)
          .startLearning('book-1');

      final state = container.read(learnControllerProvider);
      expect(state.isBookUnavailableForNextBatch, isTrue);
      expect(prefs.getString('selected_book_id'), isNull);
    },
  );

  test('resumes active session even when book is unavailable', () async {
    final session = LearningSession(
      id: 'session-1',
      userId: '1',
      sessionType: LearningSessionType.wordLearn,
      bookId: 'book-1',
      status: 'active',
      dataPayload:
          '{"words":[{"id":"word-1","word":"言葉","reading":"ことば","part_of_speech":"noun","book_sort_order":1}],"current_index":0,"batch_start_sort":0,"batch_end_sort":10}',
      createdAt: DateTime.now(),
    );

    when(
      () => sessionRepository.getActiveSession(1, 'book-1'),
    ).thenAnswer((_) async => session);

    await container
        .read(learnControllerProvider.notifier)
        .startLearning('book-1');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(learnControllerProvider);
    expect(state.words.length, 1);
    expect(state.isResumed, isTrue);
    expect(state.isBookUnavailableForNextBatch, isFalse);
  });

  test(
    'creates remote learn session and completes batch via complete endpoint',
    () async {
      var getActiveSessionCalls = 0;
      when(() => sessionRepository.getActiveSession(1, 'book-1')).thenAnswer((
        _,
      ) async {
        getActiveSessionCalls += 1;
        if (getActiveSessionCalls == 1) {
          return null;
        }

        return LearningSession.wordLearn(
          id: 'local-learn-1',
          userId: 1,
          serverSessionId: 'remote-learn-1',
          bookId: 'book-1',
          wordsPayload: encodeSessionWords([
            {
              'id': 'word-1',
              'word': '言葉',
              'reading': 'ことば',
              'part_of_speech': 'noun',
              'primary_meaning': '词语',
              'book_sort_order': 1,
              'rich_content': {'meanings': []},
              'examples': const [],
            },
          ]),
          currentIndex: 0,
          batchStartSort: 0,
          batchEndSort: 10,
          createdAt: DateTime.now(),
        );
      });
      when(
        () => remoteQuery.createLearnSession(bookId: 'book-1', limit: 10),
      ).thenAnswer(
        (_) async => RemoteWordLearnSession(
          sessionId: 'remote-learn-1',
          bookId: 'book-1',
          batchStartSort: 0,
          batchEndSort: 10,
          words: [
            WordDetailWithSort.fromJson({
              'id': 'word-1',
              'word': '言葉',
              'reading': 'ことば',
              'part_of_speech': 'noun',
              'primary_meaning': '词语',
              'book_sort_order': 1,
              'rich_content': {'meanings': []},
              'examples': const [],
            }),
          ],
          totalWords: 100,
          resumed: false,
          rawWordsJson: [
            {
              'id': 'word-1',
              'word': '言葉',
              'reading': 'ことば',
              'part_of_speech': 'noun',
              'primary_meaning': '词语',
              'book_sort_order': 1,
              'rich_content': {'meanings': []},
              'examples': const [],
            },
          ],
        ),
      );
      when(
        () => sessionRepository.createSession(any()),
      ).thenAnswer((_) async => 'local-learn-1');
      when(
        () => remoteQuery.completeLearnSession(
          sessionId: 'remote-learn-1',
          wordStates: any(named: 'wordStates'),
          firstReviewIntervalMinutes: 10,
        ),
      ).thenAnswer((_) async {});

      final notifier = container.read(learnControllerProvider.notifier);
      await notifier.startLearning('book-1');
      await notifier.markCurrentMastered();

      final state = container.read(learnControllerProvider);
      expect(state.isBatchComplete, isTrue);
      verify(
        () => remoteQuery.completeLearnSession(
          sessionId: 'remote-learn-1',
          wordStates: any(named: 'wordStates'),
          firstReviewIntervalMinutes: 10,
        ),
      ).called(1);
      verify(() => sessionRepository.deleteSession('local-learn-1')).called(1);
    },
  );
}
