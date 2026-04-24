import 'package:breeze_jp/core/providers/preferences_provider.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/book_progress_command.dart';
import 'package:breeze_jp/data/commands/book_progress_command.dart' as bp;
import 'package:breeze_jp/data/commands/study_word_command.dart';
import 'package:breeze_jp/data/commands/word_introduction_command.dart';
import 'package:breeze_jp/data/commands/word_introduction_command_provider.dart';
import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_detail.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/book_query.dart';
import 'package:breeze_jp/data/queries/book_query_provider.dart';
import 'package:breeze_jp/data/queries/vocab_remote_query.dart';
import 'package:breeze_jp/data/queries/vocab_remote_query_provider.dart';
import 'package:breeze_jp/data/queries/word_read_queries.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository_provider.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository_provider.dart';
import 'package:breeze_jp/features/learn/controller/learn_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockStudyWordCommand extends Mock implements StudyWordCommand {}

class _MockBookProgressCommand extends Mock implements BookProgressCommand {}

class _MockWordIntroductionCommand extends Mock
    implements WordIntroductionCommand {}

class _MockBookQuery extends Mock implements BookQuery {}

class _MockWordReadQueries extends Mock implements WordReadQueries {}

class _MockLearningSessionRepository extends Mock
    implements LearningSessionRepository {}

class _MockBookProgressRepository extends Mock
    implements BookProgressRepository {}

class _MockVocabRemoteQuery extends Mock implements VocabRemoteQuery {}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockStudyWordCommand studyWordCommand;
  late _MockBookProgressCommand bookProgressCommand;
  late _MockWordIntroductionCommand wordIntroductionCommand;
  late _MockBookQuery bookQuery;
  late _MockWordReadQueries wordReadQueries;
  late _MockLearningSessionRepository sessionRepository;
  late _MockBookProgressRepository progressRepository;
  late _MockVocabRemoteQuery remoteQuery;

  final user = User(id: 1, username: 'u', passwordHash: 'p');
  final wordDetail = WordDetail(
    word: Word(id: 'word-1', word: '言葉', reading: 'ことば', partOfSpeech: 'noun'),
    richContent: WordRichContent.empty(),
    examples: const [],
  );

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_book_id': 'book-1'});
    prefs = await SharedPreferences.getInstance();
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    studyWordCommand = _MockStudyWordCommand();
    bookProgressCommand = _MockBookProgressCommand();
    wordIntroductionCommand = _MockWordIntroductionCommand();
    bookQuery = _MockBookQuery();
    wordReadQueries = _MockWordReadQueries();
    sessionRepository = _MockLearningSessionRepository();
    progressRepository = _MockBookProgressRepository();
    remoteQuery = _MockVocabRemoteQuery();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(
      () => studyWordCommand.markAsLearned(
        userId: any(named: 'userId'),
        wordId: any(named: 'wordId'),
        bookId: any(named: 'bookId'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        studyWordCommandProvider.overrideWith((ref) => studyWordCommand),
        bp.bookProgressCommandProvider.overrideWith(
          (ref) => bookProgressCommand,
        ),
        wordIntroductionCommandProvider.overrideWith(
          (ref) => wordIntroductionCommand,
        ),
        bookQueryProvider.overrideWith((ref) => bookQuery),
        wordReadQueriesProvider.overrideWith((ref) => wordReadQueries),
        learningSessionRepositoryProvider.overrideWith(
          (ref) => sessionRepository,
        ),
        bookProgressRepositoryProvider.overrideWith(
          (ref) => progressRepository,
        ),
        vocabRemoteQueryProvider.overrideWith((ref) => remoteQuery),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'blocks next batch when book is unavailable and no active session',
    () async {
      when(
        () => sessionRepository.getActiveSession(1, 'book-1'),
      ).thenAnswer((_) async => null);
      when(
        () => bookQuery.isBookAvailable('book-1'),
      ).thenAnswer((_) async => false);

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
      id: 1,
      userId: 1,
      bookId: 'book-1',
      wordIds: const ['word-1'],
      currentIndex: 0,
      batchStartSort: 0,
      batchEndSort: 10,
      startedAt: DateTime.utc(2026, 4, 22),
      status: 'active',
      createdAt: DateTime.utc(2026, 4, 22),
      updatedAt: DateTime.utc(2026, 4, 22),
    );

    when(
      () => sessionRepository.getActiveSession(1, 'book-1'),
    ).thenAnswer((_) async => session);
    when(
      () => wordReadQueries.getWordDetails(['word-1'], userId: 1),
    ).thenAnswer((_) async => [wordDetail]);

    await container
        .read(learnControllerProvider.notifier)
        .startLearning('book-1');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(learnControllerProvider);
    expect(state.words.length, 1);
    expect(state.isResumed, isTrue);
    expect(state.isBookUnavailableForNextBatch, isFalse);
  });
}
