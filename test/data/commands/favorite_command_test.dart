import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/favorite_command_provider.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/models/word_example_favorite.dart';
import 'package:breeze_jp/data/models/word_favorite.dart';
import 'package:breeze_jp/data/queries/favorite_query.dart';
import 'package:breeze_jp/data/queries/favorite_query_provider.dart';
import 'package:breeze_jp/data/repositories/word_example_favorite_repository.dart';
import 'package:breeze_jp/data/repositories/word_example_favorite_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_favorite_repository.dart';
import 'package:breeze_jp/data/repositories/word_favorite_repository_provider.dart';
import 'package:breeze_jp/features/favorites/providers/favorite_refresh_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockFavoriteQuery extends Mock implements FavoriteQuery {}

class _MockWordFavoriteRepository extends Mock
    implements WordFavoriteRepository {}

class _MockWordExampleFavoriteRepository extends Mock
    implements WordExampleFavoriteRepository {}

class _MockSyncRemoteCommand extends Mock implements SyncRemoteCommand {}

void main() {
  late _MockActiveUserCommand activeUserCommand;
  late _MockFavoriteQuery favoriteQuery;
  late _MockWordFavoriteRepository wordFavoriteRepository;
  late _MockWordExampleFavoriteRepository wordExampleFavoriteRepository;
  late _MockSyncRemoteCommand syncRemoteCommand;
  late ProviderContainer container;

  final user = User(id: 1, username: 'summer', passwordHash: 'hash');
  final now = DateTime.utc(2026, 4, 28, 10, 30);

  setUpAll(() {
    registerFallbackValue(
      WordFavorite(
        id: 0,
        userId: 0,
        wordId: 'fallback-word',
        bookId: 'fallback-book',
        createdAt: DateTime.utc(2026, 4, 28),
        updatedAt: DateTime.utc(2026, 4, 28),
      ),
    );
    registerFallbackValue(
      WordExampleFavorite(
        id: 0,
        userId: 0,
        exampleId: 'fallback-example',
        wordId: 'fallback-word',
        createdAt: DateTime.utc(2026, 4, 28),
        updatedAt: DateTime.utc(2026, 4, 28),
      ),
    );
  });

  setUp(() {
    activeUserCommand = _MockActiveUserCommand();
    favoriteQuery = _MockFavoriteQuery();
    wordFavoriteRepository = _MockWordFavoriteRepository();
    wordExampleFavoriteRepository = _MockWordExampleFavoriteRepository();
    syncRemoteCommand = _MockSyncRemoteCommand();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => syncRemoteCommand.scheduleCheckpoint()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        favoriteQueryProvider.overrideWith((ref) => favoriteQuery),
        wordFavoriteRepositoryProvider.overrideWith(
          (ref) => wordFavoriteRepository,
        ),
        wordExampleFavoriteRepositoryProvider.overrideWith(
          (ref) => wordExampleFavoriteRepository,
        ),
        syncRemoteCommandProvider.overrideWith((ref) => syncRemoteCommand),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('addWordFavorite resolves book id and syncs remote', () async {
    when(
      () => favoriteQuery.resolveBookIdForWord('word-1'),
    ).thenAnswer((_) async => 'book-1');
    when(
      () => wordFavoriteRepository.getFavorite(user.id, 'word-1'),
    ).thenAnswer((_) async => null);
    when(
      () => wordFavoriteRepository.saveFavorite(any()),
    ).thenAnswer((_) async {});

    await container
        .read(favoriteCommandProvider)
        .addWordFavorite(wordId: 'word-1');
    await Future<void>.delayed(Duration.zero);

    final savedFavorite =
        verify(
              () => wordFavoriteRepository.saveFavorite(captureAny()),
            ).captured.single
            as WordFavorite;
    expect(savedFavorite.userId, user.id);
    expect(savedFavorite.wordId, 'word-1');
    expect(savedFavorite.bookId, 'book-1');

    verify(() => syncRemoteCommand.scheduleCheckpoint()).called(1);
    expect(container.read(favoriteRefreshProvider), 1);
  });

  test(
    'toggleWordFavorite removes existing favorite and returns false',
    () async {
      final existingFavorite = WordFavorite(
        id: 11,
        userId: user.id,
        wordId: 'word-1',
        bookId: 'book-1',
        createdAt: now,
        updatedAt: now,
      );

      when(
        () => wordFavoriteRepository.getFavorite(user.id, 'word-1'),
      ).thenAnswer((_) async => existingFavorite);
      when(
        () => wordFavoriteRepository.deleteFavorite(user.id, 'word-1'),
      ).thenAnswer((_) async {});

      final result = await container
          .read(favoriteCommandProvider)
          .toggleWordFavorite(wordId: 'word-1');
      await Future<void>.delayed(Duration.zero);

      expect(result, isFalse);
      verify(
        () => wordFavoriteRepository.deleteFavorite(user.id, 'word-1'),
      ).called(1);
      verify(() => syncRemoteCommand.scheduleCheckpoint()).called(1);
      expect(container.read(favoriteRefreshProvider), 1);
    },
  );

  test(
    'toggleWordExampleFavorite adds example favorite and returns true',
    () async {
      when(
        () => wordExampleFavoriteRepository.getFavorite(user.id, 'example-1'),
      ).thenAnswer((_) async => null);
      when(
        () => wordExampleFavoriteRepository.saveFavorite(any()),
      ).thenAnswer((_) async {});

      final result = await container
          .read(favoriteCommandProvider)
          .toggleWordExampleFavorite(exampleId: 'example-1', wordId: 'word-1');
      await Future<void>.delayed(Duration.zero);

      expect(result, isTrue);
      final savedFavorite =
          verify(
                () => wordExampleFavoriteRepository.saveFavorite(captureAny()),
              ).captured.single
              as WordExampleFavorite;
      expect(savedFavorite.userId, user.id);
      expect(savedFavorite.exampleId, 'example-1');
      expect(savedFavorite.wordId, 'word-1');

      verify(() => syncRemoteCommand.scheduleCheckpoint()).called(1);
      expect(container.read(favoriteRefreshProvider), 1);
    },
  );
}
