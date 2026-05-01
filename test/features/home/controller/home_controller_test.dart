import 'package:breeze_jp/core/auth/auth_provider.dart';
import 'package:breeze_jp/core/providers/home_summary_invalidation_provider.dart';
import 'package:breeze_jp/data/queries/home_query.dart';
import 'package:breeze_jp/features/home/controller/home_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeQuery extends Mock implements HomeQuery {}

class _LoginStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) {
    state = value;
  }
}

void main() {
  late _MockHomeQuery homeQuery;

  setUp(() {
    homeQuery = _MockHomeQuery();
  });

  test('guest mode skips remote home summary request', () async {
    final container = ProviderContainer(
      overrides: [
        isLoggedInProvider.overrideWith((ref) => false),
        homeQueryProvider.overrideWith((ref) => homeQuery),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeControllerProvider.notifier).loadHomeData();

    final state = container.read(homeControllerProvider);
    expect(state.isInitialized, isTrue);
    expect(state.reviewCount, 0);
    expect(state.kanaReviewCount, 0);
    expect(state.masteredWordCount, 0);
    verifyNever(() => homeQuery.fetchHomeSummary());
  });

  test('logged in mode loads local home summary', () async {
    when(() => homeQuery.fetchHomeSummary()).thenAnswer(
      (_) async => const HomeSummaryData(
        userName: 'Summer',
        reviewCount: 3,
        kanaReviewCount: 4,
        masteredWordCount: 5,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        isLoggedInProvider.overrideWith((ref) => true),
        homeQueryProvider.overrideWith((ref) => homeQuery),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeControllerProvider.notifier).loadHomeData();

    final state = container.read(homeControllerProvider);
    expect(state.userName, 'Summer');
    expect(state.reviewCount, 3);
    expect(state.kanaReviewCount, 4);
    expect(state.masteredWordCount, 5);
    verify(() => homeQuery.fetchHomeSummary()).called(1);
  });

  test(
    'home summary invalidation triggers a refresh after initialization',
    () async {
      when(() => homeQuery.fetchHomeSummary()).thenAnswer(
        (_) async => const HomeSummaryData(
          userName: 'Summer',
          reviewCount: 3,
          kanaReviewCount: 4,
          masteredWordCount: 5,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          isLoggedInProvider.overrideWith((ref) => true),
          homeQueryProvider.overrideWith((ref) => homeQuery),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeControllerProvider.notifier).loadHomeData();

      container.read(homeSummaryInvalidationProvider.notifier).markStale();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => homeQuery.fetchHomeSummary()).called(2);
    },
  );

    test('guest to logged-in transition reloads home summary', () async {
      final loginStateProvider = NotifierProvider<_LoginStateNotifier, bool>(
        _LoginStateNotifier.new,
      );

      when(() => homeQuery.fetchHomeSummary()).thenAnswer(
        (_) async => const HomeSummaryData(
          userName: 'Summer',
          reviewCount: 3,
          kanaReviewCount: 4,
          masteredWordCount: 5,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          isLoggedInProvider.overrideWith(
            (ref) => ref.watch(loginStateProvider),
          ),
          homeQueryProvider.overrideWith((ref) => homeQuery),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(homeControllerProvider, (_, __) {});
      addTearDown(subscription.close);

      await container.read(homeControllerProvider.notifier).loadHomeData();
      expect(container.read(homeControllerProvider).isInitialized, isTrue);
      verifyNever(() => homeQuery.fetchHomeSummary());

      container.read(loginStateProvider.notifier).setValue(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(homeControllerProvider);
      expect(state.userName, 'Summer');
      expect(state.reviewCount, 3);
      expect(state.kanaReviewCount, 4);
      expect(state.masteredWordCount, 5);
      verify(() => homeQuery.fetchHomeSummary()).called(1);
    });
}
