import 'package:breeze_jp/features/learn/controller/learn_controller.dart';
import 'package:breeze_jp/features/learn/pages/learn_page.dart';
import 'package:breeze_jp/features/learn/state/learn_state.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLearnController extends LearnController {
  @override
  LearnState build() => const LearnState();

  @override
  Future<void> startLearning(String bookId) async {}

  void emitBookUnavailable() {
    state = state.copyWith(isBookUnavailableForNextBatch: true);
  }
}

void main() {
  testWidgets('shows unavailable-book dialog when next batch is blocked', (
    tester,
  ) async {
    late _FakeLearnController fakeController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnControllerProvider.overrideWith(() {
            fakeController = _FakeLearnController();
            return fakeController;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LearnPage(bookId: 'book-1'),
        ),
      ),
    );

    await tester.pump();

    fakeController.emitBookUnavailable();
    await tester.pumpAndSettle();

    expect(find.text('辞书不可用'), findsOneWidget);
    expect(find.text('这本辞书已经不可用于继续学习新单词，请选择其他辞书。'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
    expect(find.text('选择辞书'), findsOneWidget);
  });
}
