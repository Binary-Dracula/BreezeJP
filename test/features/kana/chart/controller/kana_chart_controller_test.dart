import 'package:breeze_jp/data/models/kana_detail.dart';
import 'package:breeze_jp/data/models/kana_letter.dart';
import 'package:breeze_jp/data/models/read/kana_type_item.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/kana_query.dart';
import 'package:breeze_jp/data/queries/kana_query_provider.dart';
import 'package:breeze_jp/features/kana/chart/controller/kana_chart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockKanaQuery extends Mock implements KanaQuery {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

void main() {
  late _MockKanaQuery kanaQuery;
  late _MockActiveUserQuery activeUserQuery;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        kanaQueryProvider.overrideWith((ref) => kanaQuery),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
      ],
    );
  }

  setUp(() {
    kanaQuery = _MockKanaQuery();
    activeUserQuery = _MockActiveUserQuery();

    when(() => activeUserQuery.getActiveUserId()).thenAnswer((_) async => 1);
    when(
      () => kanaQuery.getAllKanaTypes(),
    ).thenAnswer((_) async => const [KanaTypeItem(type: '清音')]);
    when(() => kanaQuery.getAllKanaLettersWithState(1)).thenAnswer(
      (_) async => [
        KanaLetterWithState(
          letter: KanaLetter(
            id: 1,
            kanaChar: 'あ',
            scriptKind: KanaScriptKind.hiragana,
            romaji: 'a',
            vowel: 'a',
            rowGroup: 'あ行',
            kanaCategory: '清音',
            displayOrder: 1,
            createdAt: '2026-04-28T00:00:00Z',
            updatedAt: '2026-04-28T00:00:00Z',
          ),
        ),
      ],
    );
    when(() => kanaQuery.countTotalKana()).thenAnswer((_) async => 218);
    when(
      () => kanaQuery.countMasteredKana(userId: 1),
    ).thenAnswer((_) async => 12);
  });

  test(
    'build schedules kana loading without touching uninitialized state',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final initial = container.read(kanaChartControllerProvider);
      expect(initial.isLoading, isFalse);
      expect(initial.kanaLetters, isEmpty);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final loaded = container.read(kanaChartControllerProvider);
      expect(loaded.isLoading, isFalse);
      expect(loaded.error, isNull);
      expect(loaded.kanaTypes, ['清音']);
      expect(loaded.kanaLetters, hasLength(1));
      expect(loaded.totalCount, 218);
      expect(loaded.masteredCount, 12);
    },
  );
}
