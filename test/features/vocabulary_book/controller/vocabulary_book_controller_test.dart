import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/providers/preferences_provider.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/word_remote_command.dart';
import 'package:breeze_jp/data/commands/word_remote_command_provider.dart';
import 'package:breeze_jp/data/models/read/vocabulary_book_item.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/features/vocabulary_book/controller/vocabulary_book_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockStudyRemoteQuery extends Mock implements StudyRemoteQuery {}

class _MockWordRemoteCommand extends Mock implements WordRemoteCommand {}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockStudyRemoteQuery remoteQuery;
  late _MockWordRemoteCommand wordRemoteCommand;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

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
      const WordStateUpsert(
        wordId: 'fallback',
        bookId: 'fallback',
        userState: 1,
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
    wordRemoteCommand = _MockWordRemoteCommand();

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

    when(() => wordRemoteCommand.saveState(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        studyRemoteQueryProvider.overrideWith((ref) => remoteQuery),
        wordRemoteCommandProvider.overrideWith((ref) => wordRemoteCommand),
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

      final remotePayload =
          verify(
                () => wordRemoteCommand.saveState(captureAny()),
              ).captured.single
              as WordStateUpsert;
      expect(remotePayload.wordId, 'word-1');
      expect(remotePayload.bookId, 'book-1');
      expect(remotePayload.userState, LearningStatus.learning.value);
      expect(remotePayload.nextReviewAt, isNotNull);
      expect(remotePayload.lastReviewedAt, isNotNull);
    },
  );
}
