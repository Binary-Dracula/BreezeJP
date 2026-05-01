import 'dart:async';

import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/network/api_endpoints.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/sync_outbox_item.dart';
import 'package:breeze_jp/data/models/sync_state.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository_provider.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_grammar_repository.dart';
import 'package:breeze_jp/data/repositories/study_grammar_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';
import 'package:breeze_jp/data/repositories/sync_outbox_repository.dart';
import 'package:breeze_jp/data/repositories/sync_outbox_repository_provider.dart';
import 'package:breeze_jp/data/repositories/sync_state_repository.dart';
import 'package:breeze_jp/data/repositories/sync_state_repository_provider.dart';
import 'package:breeze_jp/data/repositories/user_repository.dart';
import 'package:breeze_jp/data/repositories/user_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_example_favorite_repository.dart';
import 'package:breeze_jp/data/repositories/word_example_favorite_repository_provider.dart';
import 'package:breeze_jp/data/repositories/word_favorite_repository.dart';
import 'package:breeze_jp/data/repositories/word_favorite_repository_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncOutboxRepository extends Mock implements SyncOutboxRepository {}

class _MockSyncStateRepository extends Mock implements SyncStateRepository {}

class _MockKanaRepository extends Mock implements KanaRepository {}

class _MockStudyWordRepository extends Mock implements StudyWordRepository {}

class _MockStudyGrammarRepository extends Mock
    implements StudyGrammarRepository {}

class _MockBookProgressRepository extends Mock
    implements BookProgressRepository {}

class _MockWordFavoriteRepository extends Mock
    implements WordFavoriteRepository {}

class _MockWordExampleFavoriteRepository extends Mock
    implements WordExampleFavoriteRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

const _testSyncUserId = 'sync-user-1';

void main() {
  late _MockSyncOutboxRepository outboxRepository;
  late _MockSyncStateRepository syncStateRepository;
  late _MockKanaRepository kanaRepository;
  late _MockStudyWordRepository studyWordRepository;
  late _MockStudyGrammarRepository studyGrammarRepository;
  late _MockBookProgressRepository bookProgressRepository;
  late _MockWordFavoriteRepository wordFavoriteRepository;
  late _MockWordExampleFavoriteRepository wordExampleFavoriteRepository;
  late _MockUserRepository userRepository;
  late Dio dio;

  const syncUserId = _testSyncUserId;
  final syncState = SyncState(syncUserId: syncUserId, deviceId: 'device-1');
  final item = SyncOutboxItem(
    id: 1,
    syncUserId: syncUserId,
    mutationId: 'mutation-1',
    entityType: 'word_state',
    entityKey: 'book-1:word-1',
    operation: 'mark_learned',
    payload:
        '{"word_id":"word-1","book_id":"book-1","user_state":1,"streak":0,"total_reviews":0,"fail_count":0}',
  );

  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(syncState);
    registerFallbackValue(item);
    registerFallbackValue(KanaLearningState(id: 0, userId: 1, kanaId: 1));
  });

  setUp(() {
    outboxRepository = _MockSyncOutboxRepository();
    syncStateRepository = _MockSyncStateRepository();
    kanaRepository = _MockKanaRepository();
    studyWordRepository = _MockStudyWordRepository();
    studyGrammarRepository = _MockStudyGrammarRepository();
    bookProgressRepository = _MockBookProgressRepository();
    wordFavoriteRepository = _MockWordFavoriteRepository();
    wordExampleFavoriteRepository = _MockWordExampleFavoriteRepository();
    userRepository = _MockUserRepository();
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    when(
      () => studyWordRepository.deleteAllByUser(any()),
    ).thenAnswer((_) async {});
    when(
      () => studyGrammarRepository.deleteAllByUser(any()),
    ).thenAnswer((_) async {});
    when(
      () => bookProgressRepository.deleteAllByUser(any()),
    ).thenAnswer((_) async {});
    when(
      () => wordFavoriteRepository.deleteAllByUser(any()),
    ).thenAnswer((_) async {});
    when(
      () => wordExampleFavoriteRepository.deleteAllByUser(any()),
    ).thenAnswer((_) async {});
    when(
      () => kanaRepository.deleteKanaLearningStatesByUser(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => kanaRepository.upsertKanaLearningState(any()),
    ).thenAnswer((_) async {});
  });

  test('dispatchPending serializes overlapping push requests', () async {
    final firstPushGate = Completer<void>();
    final firstPushStarted = Completer<void>();
    var pushCount = 0;
    var fetchCount = 0;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path == ApiEndpoints.syncPush) {
            pushCount += 1;
            if (pushCount == 1) {
              firstPushStarted.complete();
              await firstPushGate.future;
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'acked_mutations': [
                      {
                        'mutation_id': item.mutationId,
                        'entity_type': item.entityType,
                        'entity_key': item.entityKey,
                        'result_version': 1,
                        'status': 'applied',
                      },
                    ],
                    'conflicts': [],
                  },
                  'meta': {
                    'next_cursor': '1',
                    'server_time': DateTime.now().toUtc().toIso8601String(),
                  },
                },
              ),
            );
            return;
          }

          handler.next(options);
        },
      ),
    );

    when(
      () => outboxRepository.getDispatchableItems(syncUserId, limit: 50),
    ).thenAnswer((_) async {
      fetchCount += 1;
      if (fetchCount == 1) {
        return [item];
      }
      return [];
    });
    when(
      () => outboxRepository.markItemsSyncing([item.id]),
    ).thenAnswer((_) async {});
    when(
      () => outboxRepository.deleteItems([item.id]),
    ).thenAnswer((_) async {});
    when(
      () => outboxRepository.markItemFailed(
        item.id,
        lastError: any(named: 'lastError'),
        nextRetryAt: any(named: 'nextRetryAt'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => syncStateRepository.getState(syncUserId),
    ).thenAnswer((_) async => syncState);
    when(() => syncStateRepository.upsertState(any())).thenAnswer((_) async {});

    final commandProvider = Provider<SyncRemoteCommand>(
      (ref) => SyncRemoteCommand(ref, dio: dio),
    );

    final container = ProviderContainer(
      overrides: [
        syncOutboxRepositoryProvider.overrideWith((ref) => outboxRepository),
        syncStateRepositoryProvider.overrideWith((ref) => syncStateRepository),
      ],
    );
    addTearDown(container.dispose);

    final command = container.read(commandProvider);

    final first = command.dispatchPendingForTesting(syncUserId);
    await Future<void>.delayed(Duration.zero);
    final second = command.dispatchPendingForTesting(syncUserId);
    await firstPushStarted.future;

    expect(pushCount, 1);

    firstPushGate.complete();
    await Future.wait([first, second]);

    expect(pushCount, 1);
    expect(fetchCount, 2);
    verify(() => outboxRepository.markItemsSyncing([item.id])).called(1);
    verify(() => outboxRepository.deleteItems([item.id])).called(1);
  });

  test(
    'dispatchPending batches queued word mutations into follow-up push',
    () async {
      final firstPushGate = Completer<void>();
      final firstPushStarted = Completer<void>();
      final pushedMutations = <List<Map<String, dynamic>>>[];
      var fetchCount = 0;
      var queue = <SyncOutboxItem>[
        _buildOutboxItem(id: 1, mutationId: 'mutation-1', wordId: 'word-1'),
      ];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == ApiEndpoints.syncPush) {
              final requestBody = Map<String, dynamic>.from(
                options.data as Map,
              );
              final mutations = (requestBody['mutations'] as List<dynamic>)
                  .map((entry) => Map<String, dynamic>.from(entry as Map))
                  .toList();
              pushedMutations.add(mutations);

              if (pushedMutations.length == 1) {
                firstPushStarted.complete();
                await firstPushGate.future;
              }

              final ackedMutations = mutations
                  .map(
                    (mutation) => {
                      'mutation_id': mutation['mutation_id'],
                      'entity_type': mutation['entity_type'],
                      'entity_key': mutation['entity_key'],
                      'result_version': 1,
                      'status': 'applied',
                    },
                  )
                  .toList();

              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'acked_mutations': ackedMutations,
                      'conflicts': [],
                    },
                    'meta': {
                      'next_cursor': '2',
                      'server_time': DateTime.now().toUtc().toIso8601String(),
                    },
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      when(
        () => outboxRepository.getDispatchableItems(syncUserId, limit: 50),
      ).thenAnswer((_) async {
        fetchCount += 1;
        return queue
            .where(
              (entry) => entry.status == 'pending' || entry.status == 'failed',
            )
            .toList();
      });
      when(() => outboxRepository.markItemsSyncing(any())).thenAnswer((
        invocation,
      ) async {
        final ids = List<int>.from(
          invocation.positionalArguments[0] as List<int>,
        );
        queue = queue
            .map(
              (entry) => ids.contains(entry.id)
                  ? entry.copyWith(status: 'syncing')
                  : entry,
            )
            .toList();
      });
      when(() => outboxRepository.deleteItems(any())).thenAnswer((
        invocation,
      ) async {
        final ids = List<int>.from(
          invocation.positionalArguments[0] as List<int>,
        );
        queue = queue.where((entry) => !ids.contains(entry.id)).toList();
      });
      when(
        () => outboxRepository.markItemFailed(
          any(),
          lastError: any(named: 'lastError'),
          nextRetryAt: any(named: 'nextRetryAt'),
        ),
      ).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as int;
        queue = queue
            .map(
              (entry) =>
                  entry.id == id ? entry.copyWith(status: 'failed') : entry,
            )
            .toList();
      });

      when(
        () => syncStateRepository.getState(syncUserId),
      ).thenAnswer((_) async => syncState);
      when(
        () => syncStateRepository.upsertState(any()),
      ).thenAnswer((_) async {});

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(ref, dio: dio),
      );

      final container = ProviderContainer(
        overrides: [
          syncOutboxRepositoryProvider.overrideWith((ref) => outboxRepository),
          syncStateRepositoryProvider.overrideWith(
            (ref) => syncStateRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final command = container.read(commandProvider);

      final first = command.dispatchPendingForTesting(syncUserId);
      await firstPushStarted.future;

      queue = [
        ...queue,
        _buildOutboxItem(id: 2, mutationId: 'mutation-2', wordId: 'word-2'),
        _buildOutboxItem(id: 3, mutationId: 'mutation-3', wordId: 'word-3'),
        _buildOutboxItem(id: 4, mutationId: 'mutation-4', wordId: 'word-4'),
      ];

      final second = command.dispatchPendingForTesting(syncUserId);
      final third = command.dispatchPendingForTesting(syncUserId);

      expect(pushedMutations.length, 1);
      expect(pushedMutations.first.map((mutation) => mutation['mutation_id']), [
        'mutation-1',
      ]);

      firstPushGate.complete();
      await Future.wait([first, second, third]);

      expect(pushedMutations.length, 2);
      expect(pushedMutations.last.map((mutation) => mutation['mutation_id']), [
        'mutation-2',
        'mutation-3',
        'mutation-4',
      ]);
      expect(fetchCount, 2);
      expect(queue, isEmpty);
    },
  );

  test(
    'first bootstrap uploads local kana states when remote snapshot is empty',
    () async {
      final localKanaState = KanaLearningState(
        id: 1,
        userId: 1,
        kanaId: 42,
        learningStatus: LearningStatus.mastered,
        nextReviewAt: 200,
        lastReviewedAt: 100,
        streak: 3,
        totalReviews: 5,
        failCount: 1,
        interval: 4,
        easeFactor: 2.6,
        stability: 6.5,
        difficulty: 2.2,
        createdAt: 50,
        updatedAt: 150,
      );
      final queuedItems = <SyncOutboxItem>[];
      final pushedMutations = <Map<String, dynamic>>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.syncBootstrap) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'profile': null,
                      'word_states': [],
                      'kana_states': [],
                      'grammar_states': [],
                      'book_progress': [],
                      'word_favorites': [],
                      'word_example_favorites': [],
                    },
                    'meta': {'next_cursor': '10'},
                  },
                ),
              );
              return;
            }

            if (options.path == ApiEndpoints.syncPush) {
              final requestBody = Map<String, dynamic>.from(
                options.data as Map,
              );
              final mutations = (requestBody['mutations'] as List<dynamic>)
                  .map((entry) => Map<String, dynamic>.from(entry as Map))
                  .toList();
              pushedMutations.addAll(mutations);

              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'acked_mutations': mutations
                          .map(
                            (mutation) => {
                              'mutation_id': mutation['mutation_id'],
                              'entity_type': mutation['entity_type'],
                              'entity_key': mutation['entity_key'],
                              'result_version': 1,
                              'status': 'applied',
                            },
                          )
                          .toList(),
                      'conflicts': [],
                    },
                    'meta': {'next_cursor': '11'},
                  },
                ),
              );
              return;
            }

            if (options.path == ApiEndpoints.syncPull) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [],
                    'meta': {'next_cursor': '10', 'has_more': false},
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      when(
        () => syncStateRepository.getState(syncUserId),
      ).thenAnswer((_) async => syncState.copyWith(lastPulledSeq: 0));
      when(
        () => syncStateRepository.upsertState(any()),
      ).thenAnswer((_) async {});
      when(
        () => outboxRepository.getDispatchableItems(syncUserId, limit: 50),
      ).thenAnswer((_) async => List<SyncOutboxItem>.from(queuedItems));
      when(() => outboxRepository.enqueue(any())).thenAnswer((
        invocation,
      ) async {
        queuedItems.add(invocation.positionalArguments.first as SyncOutboxItem);
        return queuedItems.length;
      });
      when(() => outboxRepository.markItemsSyncing(any())).thenAnswer((
        _,
      ) async {
        queuedItems.clear();
      });
      when(() => outboxRepository.deleteItems(any())).thenAnswer((_) async {});
      when(
        () => outboxRepository.markItemFailed(
          any(),
          lastError: any(named: 'lastError'),
          nextRetryAt: any(named: 'nextRetryAt'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => kanaRepository.getAllKanaLearningStates(1),
      ).thenAnswer((_) async => [localKanaState]);

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(
          ref,
          dio: dio,
          currentSyncUserIdGetter: () => syncUserId,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          syncOutboxRepositoryProvider.overrideWith((ref) => outboxRepository),
          syncStateRepositoryProvider.overrideWith(
            (ref) => syncStateRepository,
          ),
          kanaRepositoryProvider.overrideWith((ref) => kanaRepository),
          studyWordRepositoryProvider.overrideWith(
            (ref) => studyWordRepository,
          ),
          studyGrammarRepositoryProvider.overrideWith(
            (ref) => studyGrammarRepository,
          ),
          bookProgressRepositoryProvider.overrideWith(
            (ref) => bookProgressRepository,
          ),
          wordFavoriteRepositoryProvider.overrideWith(
            (ref) => wordFavoriteRepository,
          ),
          wordExampleFavoriteRepositoryProvider.overrideWith(
            (ref) => wordExampleFavoriteRepository,
          ),
          userRepositoryProvider.overrideWith((ref) => userRepository),
        ],
      );
      addTearDown(container.dispose);

      final command = container.read(commandProvider);
      await command.syncDownForCurrentUser(localUserId: 1);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => kanaRepository.deleteKanaLearningStatesByUser(1));
      verify(() => kanaRepository.getAllKanaLearningStates(1)).called(1);
      expect(pushedMutations, hasLength(1));
      expect(pushedMutations.single['entity_type'], 'kana_state');
      expect(pushedMutations.single['operation'], 'upsert');
      expect(
        Map<String, dynamic>.from(pushedMutations.single['payload'] as Map),
        containsPair('kana_id', 42),
      );
    },
  );

  test(
    'first bootstrap replaces local kana states when remote snapshot exists',
    () async {
      final pushedMutations = <Map<String, dynamic>>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.syncBootstrap) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'profile': null,
                      'word_states': [],
                      'kana_states': [
                        {
                          'kana_id': 7,
                          'learning_status': LearningStatus.mastered.value,
                          'next_review_at': 99,
                          'last_reviewed_at': 88,
                          'streak': 2,
                          'total_reviews': 4,
                          'fail_count': 0,
                          'interval': 3,
                          'ease_factor': 2.7,
                          'stability': 5.5,
                          'difficulty': 1.2,
                          'created_at': '2026-04-28T00:00:00Z',
                          'updated_at': '2026-04-28T00:00:00Z',
                        },
                      ],
                      'grammar_states': [],
                      'book_progress': [],
                      'word_favorites': [],
                      'word_example_favorites': [],
                    },
                    'meta': {'next_cursor': '20'},
                  },
                ),
              );
              return;
            }

            if (options.path == ApiEndpoints.syncPush) {
              final requestBody = Map<String, dynamic>.from(
                options.data as Map,
              );
              final mutations = (requestBody['mutations'] as List<dynamic>)
                  .map((entry) => Map<String, dynamic>.from(entry as Map))
                  .toList();
              pushedMutations.addAll(mutations);
            }

            if (options.path == ApiEndpoints.syncPull) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [],
                    'meta': {'next_cursor': '20', 'has_more': false},
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      when(
        () => syncStateRepository.getState(syncUserId),
      ).thenAnswer((_) async => syncState.copyWith(lastPulledSeq: 0));
      when(
        () => syncStateRepository.upsertState(any()),
      ).thenAnswer((_) async {});
      when(
        () => outboxRepository.getDispatchableItems(syncUserId, limit: 50),
      ).thenAnswer((_) async => const []);
      when(
        () => outboxRepository.markItemsSyncing(any()),
      ).thenAnswer((_) async {});
      when(() => outboxRepository.deleteItems(any())).thenAnswer((_) async {});
      when(
        () => outboxRepository.markItemFailed(
          any(),
          lastError: any(named: 'lastError'),
          nextRetryAt: any(named: 'nextRetryAt'),
        ),
      ).thenAnswer((_) async {});

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(
          ref,
          dio: dio,
          currentSyncUserIdGetter: () => syncUserId,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          syncOutboxRepositoryProvider.overrideWith((ref) => outboxRepository),
          syncStateRepositoryProvider.overrideWith(
            (ref) => syncStateRepository,
          ),
          kanaRepositoryProvider.overrideWith((ref) => kanaRepository),
          studyWordRepositoryProvider.overrideWith(
            (ref) => studyWordRepository,
          ),
          studyGrammarRepositoryProvider.overrideWith(
            (ref) => studyGrammarRepository,
          ),
          bookProgressRepositoryProvider.overrideWith(
            (ref) => bookProgressRepository,
          ),
          wordFavoriteRepositoryProvider.overrideWith(
            (ref) => wordFavoriteRepository,
          ),
          wordExampleFavoriteRepositoryProvider.overrideWith(
            (ref) => wordExampleFavoriteRepository,
          ),
          userRepositoryProvider.overrideWith((ref) => userRepository),
        ],
      );
      addTearDown(container.dispose);

      final command = container.read(commandProvider);
      await command.syncDownForCurrentUser(localUserId: 1);

      verify(() => kanaRepository.deleteKanaLearningStatesByUser(1)).called(1);
      verifyNever(() => kanaRepository.getAllKanaLearningStates(1));
      verify(() => kanaRepository.upsertKanaLearningState(any())).called(1);
      expect(pushedMutations, isEmpty);
    },
  );

  test(
    'first bootstrap keeps login flow alive when kana bootstrap push times out',
    () async {
      final localKanaState = KanaLearningState(
        id: 1,
        userId: 1,
        kanaId: 42,
        learningStatus: LearningStatus.mastered,
        createdAt: 50,
        updatedAt: 150,
      );
      final queuedItems = <SyncOutboxItem>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.syncBootstrap) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'profile': null,
                      'word_states': [],
                      'kana_states': [],
                      'grammar_states': [],
                      'book_progress': [],
                      'word_favorites': [],
                      'word_example_favorites': [],
                    },
                    'meta': {'next_cursor': '10'},
                  },
                ),
              );
              return;
            }

            if (options.path == ApiEndpoints.syncPush) {
              handler.reject(
                DioException.receiveTimeout(
                  timeout: const Duration(seconds: 10),
                  requestOptions: options,
                ),
              );
              return;
            }

            if (options.path == ApiEndpoints.syncPull) {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [],
                    'meta': {'next_cursor': '10', 'has_more': false},
                  },
                ),
              );
              return;
            }

            handler.next(options);
          },
        ),
      );

      when(
        () => syncStateRepository.getState(syncUserId),
      ).thenAnswer((_) async => syncState.copyWith(lastPulledSeq: 0));
      when(
        () => syncStateRepository.upsertState(any()),
      ).thenAnswer((_) async {});
      when(
        () => outboxRepository.getDispatchableItems(syncUserId, limit: 50),
      ).thenAnswer((_) async => List<SyncOutboxItem>.from(queuedItems));
      when(() => outboxRepository.enqueue(any())).thenAnswer((invocation) async {
        queuedItems.add(invocation.positionalArguments.first as SyncOutboxItem);
        return queuedItems.length;
      });
      when(() => outboxRepository.markItemsSyncing(any())).thenAnswer((_) async {});
      when(() => outboxRepository.deleteItems(any())).thenAnswer((_) async {});
      when(
        () => outboxRepository.markItemFailed(
          any(),
          lastError: any(named: 'lastError'),
          nextRetryAt: any(named: 'nextRetryAt'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => kanaRepository.getAllKanaLearningStates(1),
      ).thenAnswer((_) async => [localKanaState]);

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(
          ref,
          dio: dio,
          currentSyncUserIdGetter: () => syncUserId,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          syncOutboxRepositoryProvider.overrideWith((ref) => outboxRepository),
          syncStateRepositoryProvider.overrideWith(
            (ref) => syncStateRepository,
          ),
          kanaRepositoryProvider.overrideWith((ref) => kanaRepository),
          studyWordRepositoryProvider.overrideWith(
            (ref) => studyWordRepository,
          ),
          studyGrammarRepositoryProvider.overrideWith(
            (ref) => studyGrammarRepository,
          ),
          bookProgressRepositoryProvider.overrideWith(
            (ref) => bookProgressRepository,
          ),
          wordFavoriteRepositoryProvider.overrideWith(
            (ref) => wordFavoriteRepository,
          ),
          wordExampleFavoriteRepositoryProvider.overrideWith(
            (ref) => wordExampleFavoriteRepository,
          ),
          userRepositoryProvider.overrideWith((ref) => userRepository),
        ],
      );
      addTearDown(container.dispose);

      final command = container.read(commandProvider);
      await command.syncDownForCurrentUser(localUserId: 1);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => kanaRepository.deleteKanaLearningStatesByUser(1));
      verify(() => kanaRepository.getAllKanaLearningStates(1)).called(1);
      verify(
        () => outboxRepository.markItemFailed(
          any(),
          lastError: any(named: 'lastError'),
          nextRetryAt: any(named: 'nextRetryAt'),
        ),
      ).called(1);
    },
  );
}

SyncOutboxItem _buildOutboxItem({
  required int id,
  required String mutationId,
  required String wordId,
}) {
  return SyncOutboxItem(
    id: id,
    syncUserId: _testSyncUserId,
    mutationId: mutationId,
    entityType: 'word_state',
    entityKey: 'book-1:$wordId',
    operation: 'mark_learned',
    payload:
        '{"word_id":"$wordId","book_id":"book-1","user_state":1,"streak":0,"total_reviews":0,"fail_count":0}',
  );
}
