import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/providers/preferences_provider.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/models/read/vocabulary_book_item.dart';
import 'package:breeze_jp/data/models/study_word.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';
import 'package:breeze_jp/features/vocabulary_book/controller/vocabulary_book_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockStudyRemoteQuery extends Mock implements StudyRemoteQuery {}

class _MockStudyWordRepository extends Mock implements StudyWordRepository {}

class _MockSyncRemoteCommand extends Mock implements SyncRemoteCommand {}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockStudyRemoteQuery remoteQuery;
  late _MockStudyWordRepository studyWordRepository;
  late _MockSyncRemoteCommand syncRemoteCommand;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

  final existingStudyWord = StudyWord(
    id: 7,
    userId: 1,
    wordId: 'word-1',
    bookId: 'book-1',
    userState: LearningStatus.mastered,
    nextReviewAt: null,
    lastReviewedAt: null,
    firstLearnedAt: DateTime.utc(2026, 4, 20),
    createdAt: DateTime.utc(2026, 4, 20),
    updatedAt: DateTime.utc(2026, 4, 20),
  );

  final masteredItem = VocabularyBookItem(
    studyWordId: 7,
    wordId: 'word-1',
    bookId: 'book-1',
    word: '言葉',
    reading: 'ことば',
    primaryMeaning: '词语',
    userState: LearningStatus.mastered,
    updatedAt: DateTime.utc(2026, 4, 20),
  );

  setUpAll(() {
    registerFallbackValue(LearningStatus.learning);
    registerFallbackValue(
      StudyWord(
        id: 0,
        userId: 0,
        wordId: 'fallback',
        bookId: 'fallback',
        userState: LearningStatus.learning,
        createdAt: DateTime.utc(2026, 4, 20),
        updatedAt: DateTime.utc(2026, 4, 20),
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'selected_book_id': 'book-1',
      'first_review_interval_minutes': 10,
    });
    prefs = await SharedPreferences.getInstance();

    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    remoteQuery = _MockStudyRemoteQuery();
    studyWordRepository = _MockStudyWordRepository();
    syncRemoteCommand = _MockSyncRemoteCommand();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);

    when(
      () => remoteQuery.fetchWordBook(
        status: any(named: 'status'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        searchQuery: any(named: 'searchQuery'),
      ),
    ).thenAnswer(
      (_) async => const RemotePagedItems<VocabularyBookItem>(
        items: [],
        totalCount: 0,
        hasMore: false,
      ),
    );

    when(
      () => studyWordRepository.getStudyWord(1, 'word-1', 'book-1'),
    ).thenAnswer((_) async => existingStudyWord);
    when(
      () => studyWordRepository.updateStudyWord(any()),
    ).thenAnswer((_) async {});
    when(() => syncRemoteCommand.scheduleCheckpoint()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        studyRemoteQueryProvider.overrideWith((ref) => remoteQuery),
        studyWordRepositoryProvider.overrideWith((ref) => studyWordRepository),
        syncRemoteCommandProvider.overrideWith((ref) => syncRemoteCommand),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'restores mastered word back to learning from vocabulary book',
    () async {
      final notifier = container.read(
        vocabularyBookControllerProvider.notifier,
      );
      notifier.switchTab(1);

      await notifier.toggleStatus(masteredItem);

      final captured =
          verify(
                () => studyWordRepository.updateStudyWord(captureAny()),
              ).captured.single
              as StudyWord;
      expect(captured.userState, LearningStatus.learning);
      expect(captured.wordId, 'word-1');
      expect(captured.bookId, 'book-1');
      expect(captured.nextReviewAt, isNotNull);

      verify(() => syncRemoteCommand.scheduleCheckpoint()).called(1);
    },
  );
}
