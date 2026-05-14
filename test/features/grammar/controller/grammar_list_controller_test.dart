import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/models/grammar.dart';
import 'package:breeze_jp/data/models/grammar_context.dart';
import 'package:breeze_jp/data/models/grammar_detail.dart';
import 'package:breeze_jp/data/models/grammar_example.dart';
import 'package:breeze_jp/data/models/grammar_meaning.dart';
import 'package:breeze_jp/data/queries/grammar_remote_query.dart';
import 'package:breeze_jp/data/queries/grammar_remote_query_provider.dart';
import 'package:breeze_jp/features/grammar/controller/grammar_list_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGrammarRemoteQuery extends Mock implements GrammarRemoteQuery {}

void main() {
  late ProviderContainer container;
  late _MockGrammarRemoteQuery remoteQuery;

  setUp(() {
    remoteQuery = _MockGrammarRemoteQuery();
    container = ProviderContainer(
      overrides: [
        grammarRemoteQueryProvider.overrideWith((ref) => remoteQuery),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('loads all remote grammar pages for the selected level', () async {
    final firstPage = List.generate(
      50,
      (index) => _detail(
        id: index + 1,
        title: 'Grammar ${index + 1}',
        status: index.isEven
            ? LearningStatus.learning
            : LearningStatus.mastered,
      ),
    );
    final capturedExcludeIds = <List<int>>[];

    when(
      () => remoteQuery.fetchGrammars(
        limit: 50,
        excludeIds: any(named: 'excludeIds'),
        jlptLevel: 'n5',
      ),
    ).thenAnswer((invocation) async {
      final excludeIds = List<int>.from(
        invocation.namedArguments[#excludeIds] as List<int>,
      );
      capturedExcludeIds.add(excludeIds);

      if (capturedExcludeIds.length == 1) {
        return firstPage;
      }

      if (capturedExcludeIds.length == 2) {
        return [
          _detail(
            id: 51,
            title: 'Grammar 51',
            status: LearningStatus.unlearned,
          ),
        ];
      }

      fail('Unexpected extra fetchGrammars call: $excludeIds');
    });

    await container.read(grammarListControllerProvider.notifier).loadGrammars();

    final state = container.read(grammarListControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.grammars.map((grammar) => grammar.id).toList(), [
      ...List.generate(50, (index) => index + 1),
      51,
    ]);
    expect(state.levelCounts['n5'], 51);
    expect(capturedExcludeIds, [
      <int>[],
      List.generate(50, (index) => index + 1),
    ]);

    verify(
      () => remoteQuery.fetchGrammars(
        limit: 50,
        excludeIds: any(named: 'excludeIds'),
        jlptLevel: 'n5',
      ),
    ).called(2);
  });
}

GrammarDetail _detail({
  required int id,
  required String title,
  required LearningStatus status,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return GrammarDetail(
    grammar: Grammar(
      id: id,
      title: title,
      jlptLevel: 'N5',
      createdAt: now,
      updatedAt: now,
      userState: status,
    ),
    meanings: [
      GrammarMeaning(id: id, grammarId: id, sortOrder: 1, definitionCn: title),
    ],
    contexts: [GrammarContext(id: id, grammarId: id, whenToUseCn: title)],
    examples: [
      GrammarExample(id: id, grammarId: id, sortOrder: 1, sentence: title),
    ],
    userState: status,
  );
}
