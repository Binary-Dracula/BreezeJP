import 'package:breeze_jp/core/auth/auth_provider.dart';
import 'package:breeze_jp/core/providers/preferences_provider.dart';
import 'package:breeze_jp/data/models/vocab_book.dart';
import 'package:breeze_jp/data/queries/book_query_provider.dart';
import 'package:breeze_jp/features/settings/pages/settings_page.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required SharedPreferences prefs,
    required Future<VocabBook?> Function() selectedBookLoader,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWith((ref) => null),
          displayNameProvider.overrideWith((ref) => null),
          selectedBookProvider.overrideWith((ref) => selectedBookLoader()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('shows selected book title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpPage(
      tester,
      prefs: prefs,
      selectedBookLoader: () async => VocabBook(id: 'book-1', title: 'N1 Core'),
    );

    expect(find.text('当前辞书'), findsOneWidget);
    expect(find.text('N1 Core'), findsOneWidget);
  });

  testWidgets('shows unselected state when no selected book exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpPage(tester, prefs: prefs, selectedBookLoader: () async => null);

    expect(find.text('未选择辞书'), findsOneWidget);
  });
}
