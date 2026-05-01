import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/active_user_command_provider.dart';
import 'package:breeze_jp/data/commands/kana_command.dart';
import 'package:breeze_jp/data/commands/kana_command_provider.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/kana_letter.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:breeze_jp/data/queries/active_user_query_provider.dart';
import 'package:breeze_jp/data/queries/kana_query.dart';
import 'package:breeze_jp/data/queries/kana_query_provider.dart';
import 'package:breeze_jp/features/kana/review/controller/kana_review_controller.dart';
import 'package:breeze_jp/features/kana/review/state/review_kana_item.dart';
import 'package:breeze_jp/features/word_review/state/word_review_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockKanaQuery extends Mock implements KanaQuery {}

class _MockKanaCommand extends Mock implements KanaCommand {}

void main() {
  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockKanaQuery kanaQuery;
  late _MockKanaCommand kanaCommand;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        activeUserCommandProvider.overrideWith((ref) => activeUserCommand),
        activeUserQueryProvider.overrideWith((ref) => activeUserQuery),
        kanaQueryProvider.overrideWith((ref) => kanaQuery),
        kanaCommandProvider.overrideWith((ref) => kanaCommand),
      ],
    );
  }

  setUp(() async {
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    kanaQuery = _MockKanaQuery();
    kanaCommand = _MockKanaCommand();

    when(
      () => activeUserCommand.ensureActiveUser(),
    ).thenAnswer((_) async => user);
    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(() => kanaQuery.getDueReviewKana(1)).thenAnswer(
      (_) async => [
        KanaLearningState(
          id: 1,
          userId: user.id,
          kanaId: 1,
          learningStatus: LearningStatus.learning,
          createdAt: 1713571200,
          updatedAt: 1713571200,
        ),
      ],
    );
    when(
      () => kanaQuery.getAllKanaLetters(),
    ).thenAnswer((_) async => _allKanaLetters());
  });

  test(
    'loads local kana review items and enters grading on correct answer',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(kanaReviewControllerProvider.notifier);
      await notifier.loadReview();

      final loaded = container.read(kanaReviewControllerProvider);
      expect(loaded.sessionId, isNull);
      expect(loaded.currentPhase, ReviewCardPhase.testing);
      expect(loaded.items, hasLength(1));
      expect(loaded.currentOptions, hasLength(4));

      final correctAnswer = _correctOptionFor(loaded.currentItem!);
      await notifier.submitObjectiveAnswer(correctAnswer);

      final resumed = container.read(kanaReviewControllerProvider);
      expect(resumed.currentPhase, ReviewCardPhase.grading);
      expect(resumed.currentItem?.kanaLetter.id, 1);
      verify(() => kanaQuery.getDueReviewKana(1)).called(1);
      verify(() => kanaQuery.getAllKanaLetters()).called(1);
    },
  );
}

List<KanaLetter> _allKanaLetters() {
  return [
    KanaLetter(
      id: 1,
      kanaChar: 'あ',
      scriptKind: KanaScriptKind.hiragana,
      romaji: 'a',
      vowel: 'a',
      pairGroupId: 100,
      displayOrder: 1,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
    KanaLetter(
      id: 2,
      kanaChar: 'い',
      scriptKind: KanaScriptKind.hiragana,
      romaji: 'i',
      vowel: 'i',
      displayOrder: 2,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
    KanaLetter(
      id: 3,
      kanaChar: 'う',
      scriptKind: KanaScriptKind.hiragana,
      romaji: 'u',
      vowel: 'u',
      displayOrder: 3,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
    KanaLetter(
      id: 4,
      kanaChar: 'え',
      scriptKind: KanaScriptKind.hiragana,
      romaji: 'e',
      vowel: 'e',
      displayOrder: 4,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
    KanaLetter(
      id: 5,
      kanaChar: 'ア',
      scriptKind: KanaScriptKind.katakana,
      romaji: 'a',
      vowel: 'a',
      pairGroupId: 100,
      displayOrder: 5,
      createdAt: '2026-04-20T00:00:00Z',
      updatedAt: '2026-04-20T00:00:00Z',
    ),
  ];
}

String _correctOptionFor(ReviewKanaItem item) {
  switch (item.questionType) {
    case ReviewQuestionType.hiraganaToRomaji:
    case ReviewQuestionType.katakanaToRomaji:
      return item.kanaLetter.romaji;
    case ReviewQuestionType.romajiToHiragana:
    case ReviewQuestionType.romajiToKatakana:
      return item.kanaLetter.kanaChar;
    case ReviewQuestionType.hiraganaToKatakana:
    case ReviewQuestionType.katakanaToHiragana:
      return item.counterpartLetter?.kanaChar ?? item.kanaLetter.kanaChar;
  }
}
