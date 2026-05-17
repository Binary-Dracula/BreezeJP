import 'package:breeze_jp/features/learn/controller/learn_controller.dart';
import 'package:breeze_jp/features/learn/pages/learn_page.dart';
import 'package:breeze_jp/features/learn/state/learn_state.dart';
import 'package:breeze_jp/data/models/word.dart';
import 'package:breeze_jp/data/models/word_detail.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLearnController extends LearnController {
  _FakeLearnController({
    LearnState initialState = const LearnState(),
    this.onStartLearning,
  }) : _initialState = initialState;

  final LearnState _initialState;
  final Future<void> Function(_FakeLearnController controller, String bookId)?
  onStartLearning;
  int startLearningCalls = 0;
  int goToNextCalls = 0;

  @override
  LearnState build() => _initialState;

  @override
  Future<void> startLearning(String bookId) async {
    startLearningCalls += 1;
    await onStartLearning?.call(this, bookId);
  }

  @override
  Future<void> goToNext() async {
    goToNextCalls += 1;
    state = state.copyWith(isBatchComplete: true);
  }

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

  testWidgets('last card next button completes batch through controller', (
    tester,
  ) async {
    late _FakeLearnController fakeController;
    final wordDetail = WordDetail(
      word: Word(
        id: 'word-1',
        word: '言葉',
        reading: 'ことば',
        partOfSpeech: 'noun',
      ),
      richContent: WordRichContent.empty(),
      examples: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnControllerProvider.overrideWith(() {
            fakeController = _FakeLearnController(
              initialState: LearnState(words: [wordDetail], bookId: 'book-1'),
            );
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
    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
    await tester.pumpAndSettle();

    expect(fakeController.goToNextCalls, 1);
  });

  testWidgets('shows fullscreen loading overlay and clamps progress text', (
    tester,
  ) async {
    late _FakeLearnController fakeController;
    final wordDetail = WordDetail(
      word: Word(
        id: 'word-1',
        word: '言葉',
        reading: 'ことば',
        partOfSpeech: 'noun',
      ),
      richContent: WordRichContent.empty(),
      examples: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnControllerProvider.overrideWith(() {
            fakeController = _FakeLearnController(
              initialState: LearnState(
                words: [wordDetail],
                currentIndex: 1,
                isLoading: true,
                bookId: 'book-1',
              ),
            );
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

    expect(find.byKey(const Key('learn_loading_overlay')), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets(
    'does not show empty-state text while initial loading is active',
    (tester) async {
      late _FakeLearnController fakeController;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnControllerProvider.overrideWith(() {
              fakeController = _FakeLearnController(
                initialState: const LearnState(
                  isLoading: true,
                  bookId: 'book-1',
                ),
              );
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

      expect(find.byKey(const Key('learn_loading_overlay')), findsOneWidget);
      expect(find.text('没有可学习的单词'), findsNothing);
    },
  );

  testWidgets('defers initial provider updates until after first build', (
    tester,
  ) async {
    late _FakeLearnController fakeController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnControllerProvider.overrideWith(() {
            fakeController = _FakeLearnController(
              onStartLearning: (controller, bookId) async {
                controller.state = controller.state.copyWith(
                  isLoading: true,
                  bookId: bookId,
                );
              },
            );
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

    expect(find.byKey(const Key('learn_loading_overlay')), findsOneWidget);
    expect(find.text('没有可学习的单词'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump();

    expect(fakeController.startLearningCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
