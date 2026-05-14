import 'package:breeze_jp/core/algorithm/algorithm_service.dart';
import 'package:breeze_jp/core/algorithm/algorithm_service_provider.dart';
import 'package:breeze_jp/core/algorithm/srs_types.dart';
import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/providers/home_summary_invalidation_provider.dart';
import 'package:breeze_jp/data/commands/grammar_command.dart';
import 'package:breeze_jp/data/commands/grammar_remote_command.dart';
import 'package:breeze_jp/data/commands/grammar_remote_command_provider.dart';
import 'package:breeze_jp/data/models/grammar.dart';
import 'package:breeze_jp/data/models/grammar_context.dart';
import 'package:breeze_jp/data/models/grammar_detail.dart';
import 'package:breeze_jp/data/models/grammar_example.dart';
import 'package:breeze_jp/data/models/grammar_meaning.dart';
import 'package:breeze_jp/data/models/study_grammar.dart';
import 'package:breeze_jp/data/queries/grammar_remote_query.dart';
import 'package:breeze_jp/data/queries/grammar_remote_query_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGrammarRemoteCommand extends Mock implements GrammarRemoteCommand {}

class _MockGrammarRemoteQuery extends Mock implements GrammarRemoteQuery {}

void main() {
  late ProviderContainer container;
  late _MockGrammarRemoteCommand remoteCommand;
  late _MockGrammarRemoteQuery remoteQuery;
  late AlgorithmService algorithmService;

  setUpAll(() {
    registerFallbackValue(<GrammarStateUpsert>[]);
  });

  setUp(() {
    remoteCommand = _MockGrammarRemoteCommand();
    remoteQuery = _MockGrammarRemoteQuery();
    algorithmService = AlgorithmService();
    algorithmService.setPreferredAlgorithm(AlgorithmType.sm2);

    when(() => remoteCommand.saveStates(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        grammarRemoteCommandProvider.overrideWith((ref) => remoteCommand),
        grammarRemoteQueryProvider.overrideWith((ref) => remoteQuery),
        algorithmServiceProvider.overrideWith((ref) => algorithmService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'startLearning initializes missing remote state and saves remotely',
    () async {
      when(
        () => remoteQuery.fetchGrammarDetail(101),
      ).thenAnswer((_) async => _grammarDetail(grammarId: 101));

      await container.read(grammarCommandProvider).startLearning(7, 101);

      final captured =
          verify(() => remoteCommand.saveStates(captureAny())).captured.single
              as List<GrammarStateUpsert>;
      final state = captured.single;

      expect(state.grammarId, 101);
      expect(state.learningStatus, LearningStatus.learning.value);
      expect(state.totalReviews, 1);
      expect(state.streak, 1);
      expect(state.nextReviewAt, isNotNull);
      expect(container.read(homeSummaryInvalidationProvider), 1);
    },
  );

  test('markAsMastered preserves existing remote scheduling fields', () async {
    final existingState = StudyGrammar(
      id: 0,
      userId: 0,
      grammarId: 101,
      learningStatus: LearningStatus.learning.value,
      nextReviewAt: DateTime.utc(2026, 1, 2),
      lastReviewedAt: DateTime.utc(2026, 1, 1),
      streak: 3,
      totalReviews: 4,
      failCount: 1,
      interval: 8,
      easeFactor: 2.4,
      stability: 0.5,
      difficulty: 0.6,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    when(() => remoteQuery.fetchGrammarDetail(101)).thenAnswer(
      (_) async => _grammarDetail(grammarId: 101, learningState: existingState),
    );

    await container.read(grammarCommandProvider).markAsMastered(7, 101);

    final captured =
        verify(() => remoteCommand.saveStates(captureAny())).captured.single
            as List<GrammarStateUpsert>;
    final state = captured.single;

    expect(state.grammarId, 101);
    expect(state.learningStatus, LearningStatus.mastered.value);
    expect(state.nextReviewAt, isNull);
    expect(state.totalReviews, 4);
    expect(state.failCount, 1);
    expect(state.interval, 8);
    expect(state.easeFactor, 2.4);
    expect(state.stability, 0.5);
    expect(state.difficulty, 0.6);
    expect(container.read(homeSummaryInvalidationProvider), 1);
  });
}

GrammarDetail _grammarDetail({
  required int grammarId,
  StudyGrammar? learningState,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return GrammarDetail(
    grammar: Grammar(
      id: grammarId,
      title: 'Grammar $grammarId',
      jlptLevel: 'N5',
      createdAt: now,
      updatedAt: now,
      userState: learningState == null
          ? LearningStatus.unlearned
          : LearningStatus.fromValue(learningState.learningStatus),
    ),
    meanings: [
      GrammarMeaning(
        id: grammarId,
        grammarId: grammarId,
        sortOrder: 1,
        definitionCn: 'definition',
      ),
    ],
    contexts: [
      GrammarContext(id: grammarId, grammarId: grammarId, whenToUseCn: 'usage'),
    ],
    examples: [
      GrammarExample(
        id: grammarId,
        grammarId: grammarId,
        sortOrder: 1,
        sentence: 'sentence',
      ),
    ],
    userState: learningState == null
        ? LearningStatus.unlearned
        : LearningStatus.fromValue(learningState.learningStatus),
    learningState: learningState,
  );
}
