import 'package:breeze_jp/data/commands/favorite_command_provider.dart';
import 'package:breeze_jp/data/commands/favorite_remote_command.dart';
import 'package:breeze_jp/data/commands/favorite_remote_command_provider.dart';
import 'package:breeze_jp/features/favorites/providers/favorite_refresh_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavoriteRemoteCommand extends Mock
    implements FavoriteRemoteCommand {}

void main() {
  late _MockFavoriteRemoteCommand favoriteRemoteCommand;
  late ProviderContainer container;

  setUp(() {
    favoriteRemoteCommand = _MockFavoriteRemoteCommand();

    container = ProviderContainer(
      overrides: [
        favoriteRemoteCommandProvider.overrideWith(
          (ref) => favoriteRemoteCommand,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('addWordFavorite ensures favorite via remote toggle', () async {
    when(
      () => favoriteRemoteCommand.toggleWordFavorite(wordId: 'word-1'),
    ).thenAnswer((_) async => const FavoriteToggleResult(favorited: true));

    await container
        .read(favoriteCommandProvider)
        .addWordFavorite(wordId: 'word-1');
    await Future<void>.delayed(Duration.zero);

    verify(
      () => favoriteRemoteCommand.toggleWordFavorite(wordId: 'word-1'),
    ).called(1);
    expect(container.read(favoriteRefreshProvider), 1);
  });

  test('toggleWordFavorite returns remote result and bumps refresh', () async {
    when(
      () => favoriteRemoteCommand.toggleWordFavorite(wordId: 'word-1'),
    ).thenAnswer((_) async => const FavoriteToggleResult(favorited: false));

    final result = await container
        .read(favoriteCommandProvider)
        .toggleWordFavorite(wordId: 'word-1');
    await Future<void>.delayed(Duration.zero);

    expect(result, isFalse);
    verify(
      () => favoriteRemoteCommand.toggleWordFavorite(wordId: 'word-1'),
    ).called(1);
    expect(container.read(favoriteRefreshProvider), 1);
  });

  test(
    'toggleWordExampleFavorite returns remote result and bumps refresh',
    () async {
      when(
        () => favoriteRemoteCommand.toggleWordExampleFavorite(
          exampleId: 'example-1',
          wordId: 'word-1',
        ),
      ).thenAnswer((_) async => const FavoriteToggleResult(favorited: true));

      final result = await container
          .read(favoriteCommandProvider)
          .toggleWordExampleFavorite(exampleId: 'example-1', wordId: 'word-1');
      await Future<void>.delayed(Duration.zero);

      expect(result, isTrue);
      verify(
        () => favoriteRemoteCommand.toggleWordExampleFavorite(
          exampleId: 'example-1',
          wordId: 'word-1',
        ),
      ).called(1);
      expect(container.read(favoriteRefreshProvider), 1);
    },
  );

  test(
    'removeWordExampleFavorite retries until target state is false',
    () async {
      var callCount = 0;
      when(
        () => favoriteRemoteCommand.toggleWordExampleFavorite(
          exampleId: 'example-1',
          wordId: 'word-1',
        ),
      ).thenAnswer((_) async {
        callCount++;
        return FavoriteToggleResult(favorited: callCount == 1);
      });

      await container
          .read(favoriteCommandProvider)
          .removeWordExampleFavorite(exampleId: 'example-1', wordId: 'word-1');
      await Future<void>.delayed(Duration.zero);

      verify(
        () => favoriteRemoteCommand.toggleWordExampleFavorite(
          exampleId: 'example-1',
          wordId: 'word-1',
        ),
      ).called(2);
      expect(container.read(favoriteRefreshProvider), 1);
    },
  );
}
