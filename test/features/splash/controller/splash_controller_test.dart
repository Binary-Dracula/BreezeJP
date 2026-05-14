import 'package:breeze_jp/core/auth/auth_provider.dart';
import 'package:breeze_jp/data/commands/app_bootstrap_command.dart';
import 'package:breeze_jp/data/commands/app_bootstrap_command_provider.dart';
import 'package:breeze_jp/data/queries/home_query.dart';
import 'package:breeze_jp/features/splash/controller/splash_controller.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppBootstrapCommand extends Mock implements AppBootstrapCommand {}

class _MockHomeQuery extends Mock implements HomeQuery {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAppBootstrapCommand bootstrapCommand;
  late _MockHomeQuery homeQuery;

  setUp(() {
    bootstrapCommand = _MockAppBootstrapCommand();
    homeQuery = _MockHomeQuery();

    when(() => bootstrapCommand.run()).thenAnswer(
      (_) async => const AppBootstrapResult(AppBootstrapStatus.ready),
    );
    when(() => homeQuery.fetchHomeSummary()).thenAnswer(
      (_) async => const HomeSummaryData(
        userName: 'Summer',
        reviewCount: 1,
        kanaReviewCount: 2,
        masteredWordCount: 3,
      ),
    );
  });

  Future<(BuildContext, ProviderContainer)> _pumpHarness(
    WidgetTester tester, {
    required bool isLoggedIn,
  }) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapCommandProvider.overrideWith((ref) => bootstrapCommand),
          homeQueryProvider.overrideWith((ref) => homeQuery),
          isLoggedInProvider.overrideWith((ref) => isLoggedIn),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(capturedContext);
    return (capturedContext, container);
  }

  testWidgets('guest initialize skips home summary loading', (tester) async {
    final (context, container) = await _pumpHarness(tester, isLoggedIn: false);

    final initializeFuture = container
        .read(splashControllerProvider.notifier)
        .initialize(context);
    await tester.pump(const Duration(milliseconds: 600));
    await initializeFuture;

    final state = container.read(splashControllerProvider);
    expect(state.isInitialized, isTrue);
    verify(() => bootstrapCommand.run()).called(1);
    verifyNever(() => homeQuery.fetchHomeSummary());
  });

  testWidgets('logged in initialize loads home summary', (tester) async {
    final (context, container) = await _pumpHarness(tester, isLoggedIn: true);

    final initializeFuture = container
        .read(splashControllerProvider.notifier)
        .initialize(context);
    await tester.pump(const Duration(milliseconds: 600));
    await initializeFuture;

    final state = container.read(splashControllerProvider);
    expect(state.isInitialized, isTrue);
    verify(() => bootstrapCommand.run()).called(1);
    verify(() => homeQuery.fetchHomeSummary()).called(1);
  });
}
