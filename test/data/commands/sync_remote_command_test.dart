import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/core/network/api_endpoints.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/models/kana_learning_state.dart';
import 'package:breeze_jp/data/models/sync_state.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository_provider.dart';
import 'package:breeze_jp/data/repositories/kana_repository.dart';
import 'package:breeze_jp/data/repositories/kana_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_grammar_repository.dart';
import 'package:breeze_jp/data/repositories/study_grammar_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';
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

class _MockSyncStateRepository extends Mock implements SyncStateRepository {}
class _MockKanaRepository extends Mock implements KanaRepository {}
class _MockStudyWordRepository extends Mock implements StudyWordRepository {}
class _MockStudyGrammarRepository extends Mock implements StudyGrammarRepository {}
class _MockBookProgressRepository extends Mock implements BookProgressRepository {}
class _MockWordFavoriteRepository extends Mock implements WordFavoriteRepository {}
class _MockWordExampleFavoriteRepository extends Mock implements WordExampleFavoriteRepository {}
class _MockUserRepository extends Mock implements UserRepository {}

const _testSyncUserId = 'sync-user-1';

ProviderContainer _buildContainer({
  required _MockSyncStateRepository syncStateRepository,
  required _MockKanaRepository kanaRepository,
  required _MockStudyWordRepository studyWordRepository,
  required _MockStudyGrammarRepository studyGrammarRepository,
  required _MockBookProgressRepository bookProgressRepository,
  required _MockWordFavoriteRepository wordFavoriteRepository,
  required _MockWordExampleFavoriteRepository wordExampleFavoriteRepository,
  required _MockUserRepository userRepository,
}) {
  return ProviderContainer(
    overrides: [
      syncStateRepositoryProvider.overrideWith((ref) => syncStateRepository),
      kanaRepositoryProvider.overrideWith((ref) => kanaRepository),
      studyWordRepositoryProvider.overrideWith((ref) => studyWordRepository),
      studyGrammarRepositoryProvider.overrideWith((ref) => studyGrammarRepository),
      bookProgressRepositoryProvider.overrideWith((ref) => bookProgressRepository),
      wordFavoriteRepositoryProvider.overrideWith((ref) => wordFavoriteRepository),
      wordExampleFavoriteRepositoryProvider.overrideWith((ref) => wordExampleFavoriteRepository),
      userRepositoryProvider.overrideWith((ref) => userRepository),
    ],
  );
}

void main() {
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

  Map<String, dynamic> emptyCheckpointResponse() => {
        'data': {
          'profile': null,
          'word_states': [],
          'kana_states': [],
          'grammar_states': [],
          'book_progress': [],
          'word_favorites': [],
          'word_example_favorites': [],
        },
        'meta': {
          'server_time': DateTime.now().toUtc().toIso8601String(),
          'active_device_id': 'device-1',
          'took_over': false,
          'displaced': false,
        },
      };

  setUpAll(() {
    registerFallbackValue(syncState);
    registerFallbackValue(KanaLearningState(id: 0, userId: 1, kanaId: 1));
  });

  setUp(() {
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
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    when(() => studyWordRepository.getAllByUser(any())).thenAnswer((_) async => []);
    when(() => kanaRepository.getAllKanaLearningStates(any())).thenAnswer((_) async => []);
    when(() => studyGrammarRepository.getAllByUser(any())).thenAnswer((_) async => []);
    when(() => bookProgressRepository.getAllByUser(any())).thenAnswer((_) async => []);
    when(() => wordFavoriteRepository.getAllByUser(any())).thenAnswer((_) async => []);
    when(() => wordExampleFavoriteRepository.getAllByUser(any())).thenAnswer((_) async => []);

    when(() => studyWordRepository.deleteAllByUser(any())).thenAnswer((_) async {});
    when(() => studyGrammarRepository.deleteAllByUser(any())).thenAnswer((_) async {});
    when(() => bookProgressRepository.deleteAllByUser(any())).thenAnswer((_) async {});
    when(() => wordFavoriteRepository.deleteAllByUser(any())).thenAnswer((_) async {});
    when(() => wordExampleFavoriteRepository.deleteAllByUser(any())).thenAnswer((_) async {});
    when(() => kanaRepository.deleteKanaLearningStatesByUser(any())).thenAnswer((_) async => 0);
    when(() => kanaRepository.upsertKanaLearningState(any())).thenAnswer((_) async {});

    when(() => syncStateRepository.getState(syncUserId)).thenAnswer((_) async => syncState);
    when(() => syncStateRepository.upsertState(any())).thenAnswer((_) async {});
  });

  test(
    'checkpointForCurrentUser sends POST to checkpoint endpoint with force_takeover=true',
    () async {
      final capturedBodies = <Map<String, dynamic>>[];

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.syncCheckpoint) {
            capturedBodies.add(Map<String, dynamic>.from(options.data as Map));
            handler.resolve(Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: emptyCheckpointResponse(),
            ));
            return;
          }
          handler.next(options);
        },
      ));

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(ref, dio: dio, currentSyncUserIdGetter: () => syncUserId),
      );
      final container = _buildContainer(
        syncStateRepository: syncStateRepository,
        kanaRepository: kanaRepository,
        studyWordRepository: studyWordRepository,
        studyGrammarRepository: studyGrammarRepository,
        bookProgressRepository: bookProgressRepository,
        wordFavoriteRepository: wordFavoriteRepository,
        wordExampleFavoriteRepository: wordExampleFavoriteRepository,
        userRepository: userRepository,
      );
      addTearDown(container.dispose);

      await container.read(commandProvider).checkpointForCurrentUser(localUserId: 1);

      expect(capturedBodies, hasLength(1));
      expect(capturedBodies.single['device_id'], 'device-1');
      expect(capturedBodies.single['force_takeover'], isTrue);
    },
  );

  test(
    'checkpointForCurrentUser replaces local kana states with server response',
    () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.syncCheckpoint) {
            handler.resolve(Response<Map<String, dynamic>>(
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
                      'interval': 3.0,
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
                'meta': {
                  'server_time': DateTime.now().toUtc().toIso8601String(),
                  'active_device_id': 'device-1',
                  'took_over': false,
                  'displaced': false,
                },
              },
            ));
            return;
          }
          handler.next(options);
        },
      ));

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(ref, dio: dio, currentSyncUserIdGetter: () => syncUserId),
      );
      final container = _buildContainer(
        syncStateRepository: syncStateRepository,
        kanaRepository: kanaRepository,
        studyWordRepository: studyWordRepository,
        studyGrammarRepository: studyGrammarRepository,
        bookProgressRepository: bookProgressRepository,
        wordFavoriteRepository: wordFavoriteRepository,
        wordExampleFavoriteRepository: wordExampleFavoriteRepository,
        userRepository: userRepository,
      );
      addTearDown(container.dispose);

      await container.read(commandProvider).checkpointForCurrentUser(localUserId: 1);

      verify(() => kanaRepository.deleteKanaLearningStatesByUser(1)).called(1);
      final captured = verify(
        () => kanaRepository.upsertKanaLearningState(captureAny()),
      ).captured.single as KanaLearningState;
      expect(captured.kanaId, 7);
      expect(captured.learningStatus, LearningStatus.mastered);
    },
  );

  test(
    'checkpointForCurrentUser handles displaced=true: does not replace local data',
    () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.syncCheckpoint) {
            handler.resolve(Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'profile': null,
                  'word_states': [],
                  'kana_states': [{'kana_id': 99, 'learning_status': 1}],
                  'grammar_states': [],
                  'book_progress': [],
                  'word_favorites': [],
                  'word_example_favorites': [],
                },
                'meta': {
                  'server_time': DateTime.now().toUtc().toIso8601String(),
                  'active_device_id': 'device-other',
                  'took_over': false,
                  'displaced': true,
                },
              },
            ));
            return;
          }
          handler.next(options);
        },
      ));

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(ref, dio: dio, currentSyncUserIdGetter: () => syncUserId),
      );
      final container = _buildContainer(
        syncStateRepository: syncStateRepository,
        kanaRepository: kanaRepository,
        studyWordRepository: studyWordRepository,
        studyGrammarRepository: studyGrammarRepository,
        bookProgressRepository: bookProgressRepository,
        wordFavoriteRepository: wordFavoriteRepository,
        wordExampleFavoriteRepository: wordExampleFavoriteRepository,
        userRepository: userRepository,
      );
      addTearDown(container.dispose);

      await container.read(commandProvider).checkpointForCurrentUser(localUserId: 1);

      // displaced 时不应清理/替换本地数据
      verifyNever(() => kanaRepository.deleteKanaLearningStatesByUser(any()));
      verifyNever(() => kanaRepository.upsertKanaLearningState(any()));

      // syncDisplacedProvider 应被设为 true
      expect(container.read(syncDisplacedProvider), isTrue);
    },
  );

  test(
    'checkpointForCurrentUser allocates new deviceId when none exists',
    () async {
      when(() => syncStateRepository.getState(syncUserId))
          .thenAnswer((_) async => SyncState(syncUserId: syncUserId));

      final capturedBodies = <Map<String, dynamic>>[];
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == ApiEndpoints.syncCheckpoint) {
            capturedBodies.add(Map<String, dynamic>.from(options.data as Map));
            handler.resolve(Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: emptyCheckpointResponse(),
            ));
            return;
          }
          handler.next(options);
        },
      ));

      final commandProvider = Provider<SyncRemoteCommand>(
        (ref) => SyncRemoteCommand(ref, dio: dio, currentSyncUserIdGetter: () => syncUserId),
      );
      final container = _buildContainer(
        syncStateRepository: syncStateRepository,
        kanaRepository: kanaRepository,
        studyWordRepository: studyWordRepository,
        studyGrammarRepository: studyGrammarRepository,
        bookProgressRepository: bookProgressRepository,
        wordFavoriteRepository: wordFavoriteRepository,
        wordExampleFavoriteRepository: wordExampleFavoriteRepository,
        userRepository: userRepository,
      );
      addTearDown(container.dispose);

      await container.read(commandProvider).checkpointForCurrentUser(localUserId: 1);

      expect(capturedBodies, hasLength(1));
      final deviceId = capturedBodies.single['device_id'] as String?;
      expect(deviceId, isNotNull);
      expect(deviceId, isNotEmpty);

      final savedStates = verify(
        () => syncStateRepository.upsertState(captureAny()),
      ).captured;
      expect(savedStates, isNotEmpty);
    },
  );
}
