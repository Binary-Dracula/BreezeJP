import 'package:breeze_jp/data/commands/favorite_command.dart';
import 'package:breeze_jp/data/commands/favorite_command_provider.dart';
import 'package:breeze_jp/data/models/read/example_favorite_item.dart';
import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:breeze_jp/data/queries/study_remote_query_provider.dart';
import 'package:breeze_jp/features/favorites/controller/example_favorites_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStudyRemoteQuery extends Mock implements StudyRemoteQuery {}

class _MockFavoriteCommand extends Mock implements FavoriteCommand {}

void main() {
  late _MockStudyRemoteQuery studyRemoteQuery;
  late _MockFavoriteCommand favoriteCommand;
  late ProviderContainer container;

  final firstItem = ExampleFavoriteItem(
    exampleId: 'example-1',
    wordId: 'word-1',
    word: '言葉',
    reading: 'ことば',
    japanese: '言葉を覚えます。',
    chinese: '记住词语。',
    hasAudio: false,
    updatedAt: DateTime.utc(2026, 4, 28),
    jlptLevel: 'N4',
    partOfSpeech: '名词',
    primaryMeaning: '词语',
  );
  final secondItem = ExampleFavoriteItem(
    exampleId: 'example-2',
    wordId: 'word-2',
    word: '文章',
    reading: 'ぶんしょう',
    japanese: '文章を読みます。',
    chinese: '阅读文章。',
    hasAudio: true,
    updatedAt: DateTime.utc(2026, 4, 28, 1),
    jlptLevel: 'N3',
    partOfSpeech: '名词',
    primaryMeaning: '文章',
  );

  setUp(() {
    studyRemoteQuery = _MockStudyRemoteQuery();
    favoriteCommand = _MockFavoriteCommand();

    container = ProviderContainer(
      overrides: [
        studyRemoteQueryProvider.overrideWith((ref) => studyRemoteQuery),
        favoriteCommandProvider.overrideWith((ref) => favoriteCommand),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('loadInitial populates first page of example favorites', () async {
    when(
      () => studyRemoteQuery.fetchWordExampleFavorites(
        limit: 20,
        offset: 0,
        searchQuery: null,
      ),
    ).thenAnswer(
      (_) async => RemotePagedItems<ExampleFavoriteItem>(
        items: [firstItem],
        totalCount: 1,
        hasMore: false,
      ),
    );

    await container
        .read(exampleFavoritesControllerProvider.notifier)
        .loadInitial();

    final state = container.read(exampleFavoritesControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.items, [firstItem]);
    expect(state.totalCount, 1);
    expect(state.hasMore, isFalse);
    expect(state.error, isNull);
  });

  test('loadMore appends next page items', () async {
    when(
      () => studyRemoteQuery.fetchWordExampleFavorites(
        limit: 20,
        offset: 0,
        searchQuery: null,
      ),
    ).thenAnswer(
      (_) async => RemotePagedItems<ExampleFavoriteItem>(
        items: [firstItem],
        totalCount: 2,
        hasMore: true,
      ),
    );
    when(
      () => studyRemoteQuery.fetchWordExampleFavorites(
        limit: 20,
        offset: 1,
        searchQuery: null,
      ),
    ).thenAnswer(
      (_) async => RemotePagedItems<ExampleFavoriteItem>(
        items: [secondItem],
        totalCount: 2,
        hasMore: false,
      ),
    );

    final notifier = container.read(
      exampleFavoritesControllerProvider.notifier,
    );
    await notifier.loadInitial();
    await notifier.loadMore();

    final state = container.read(exampleFavoritesControllerProvider);
    expect(state.isLoadingMore, isFalse);
    expect(state.items, [firstItem, secondItem]);
    expect(state.hasMore, isFalse);
  });

  test('search trims query before remote fetch', () async {
    when(
      () => studyRemoteQuery.fetchWordExampleFavorites(
        limit: 20,
        offset: 0,
        searchQuery: '言葉',
      ),
    ).thenAnswer(
      (_) async => const RemotePagedItems<ExampleFavoriteItem>(
        items: [],
        totalCount: 0,
        hasMore: false,
      ),
    );

    await container
        .read(exampleFavoritesControllerProvider.notifier)
        .search('  言葉  ');

    final state = container.read(exampleFavoritesControllerProvider);
    expect(state.searchQuery, '  言葉  ');
    verify(
      () => studyRemoteQuery.fetchWordExampleFavorites(
        limit: 20,
        offset: 0,
        searchQuery: '言葉',
      ),
    ).called(1);
  });

  test('unfavorite delegates to favorite command', () async {
    when(
      () => favoriteCommand.removeWordExampleFavorite(
        exampleId: 'example-1',
        wordId: 'word-1',
      ),
    ).thenAnswer((_) async {});

    await container
        .read(exampleFavoritesControllerProvider.notifier)
        .unfavorite(firstItem);

    verify(
      () => favoriteCommand.removeWordExampleFavorite(
        exampleId: 'example-1',
        wordId: 'word-1',
      ),
    ).called(1);
  });
}
