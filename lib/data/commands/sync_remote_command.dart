import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:uuid/uuid.dart';

import '../../core/constants/learning_status.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/providers/home_summary_invalidation_provider.dart';
import '../../core/utils/app_logger.dart';
import '../models/book_progress.dart';
import '../models/kana_learning_state.dart';
import '../models/study_grammar.dart';
import '../models/study_word.dart';
import '../models/sync_outbox_item.dart';
import '../models/sync_state.dart';
import '../models/word_example_favorite.dart';
import '../models/word_favorite.dart';
import '../repositories/book_progress_repository.dart';
import '../repositories/book_progress_repository_provider.dart';
import '../repositories/sync_outbox_repository.dart';
import '../repositories/sync_outbox_repository_provider.dart';
import '../repositories/sync_state_repository.dart';
import '../repositories/sync_state_repository_provider.dart';
import '../repositories/study_grammar_repository.dart';
import '../repositories/study_grammar_repository_provider.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kana_repository_provider.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_repository_provider.dart';
import '../repositories/word_example_favorite_repository.dart';
import '../repositories/word_example_favorite_repository_provider.dart';
import '../repositories/word_favorite_repository.dart';
import '../repositories/word_favorite_repository_provider.dart';

final syncRemoteCommandProvider = Provider<SyncRemoteCommand>((ref) {
  return SyncRemoteCommand(ref);
});

class SyncRemoteCommand {
  SyncRemoteCommand(
    this.ref, {
    Dio? dio,
    String? Function()? currentSyncUserIdGetter,
  }) : _dio = dio ?? DioClient.instance.dio,
       _currentSyncUserIdGetter = currentSyncUserIdGetter;

  static const _uuid = Uuid();
  static const _retryDelaySeconds = 30;

  final Ref ref;
  final Dio _dio;
  final String? Function()? _currentSyncUserIdGetter;
  Future<void>? _dispatchInFlight;
  bool _dispatchQueued = false;

  SyncStateRepository get _syncStateRepo =>
      ref.read(syncStateRepositoryProvider);
  SyncOutboxRepository get _outboxRepo =>
      ref.read(syncOutboxRepositoryProvider);
  StudyWordRepository get _studyWordRepo =>
      ref.read(studyWordRepositoryProvider);
  KanaRepository get _kanaRepo => ref.read(kanaRepositoryProvider);
  StudyGrammarRepository get _grammarRepo =>
      ref.read(studyGrammarRepositoryProvider);
  BookProgressRepository get _bookProgressRepo =>
      ref.read(bookProgressRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  WordFavoriteRepository get _wordFavoriteRepo =>
      ref.read(wordFavoriteRepositoryProvider);
  WordExampleFavoriteRepository get _wordExampleFavoriteRepo =>
      ref.read(wordExampleFavoriteRepositoryProvider);
  HomeSummaryInvalidationNotifier get _homeSummaryInvalidation =>
      ref.read(homeSummaryInvalidationProvider.notifier);

  Future<void> pushWordState({
    required StudyWord state,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'word_state',
      entityKey: '${state.bookId}:${state.wordId}',
      operation: operation,
      payload: {
        'word_id': state.wordId,
        'book_id': state.bookId,
        'user_state': state.userState.value,
        'next_review_at': _dateTimeToSeconds(state.nextReviewAt),
        'last_reviewed_at': _dateTimeToSeconds(state.lastReviewedAt),
        'first_learned_at': _dateTimeToSeconds(state.firstLearnedAt),
        'interval': state.interval,
        'ease_factor': state.easeFactor,
        'stability': state.stability,
        'difficulty': state.difficulty,
        'streak': state.streak,
        'total_reviews': state.totalReviews,
        'fail_count': state.failCount,
      },
    );
  }

  Future<void> pushKanaState({
    required KanaLearningState state,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'kana_state',
      entityKey: state.kanaId.toString(),
      operation: operation,
      payload: _kanaStatePayload(state),
    );
  }

  Future<void> pushGrammarState({
    required StudyGrammar state,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'grammar_state',
      entityKey: state.grammarId.toString(),
      operation: operation,
      payload: {
        'grammar_id': state.grammarId,
        'learning_status': state.learningStatus,
        'next_review_at': _dateTimeToSeconds(state.nextReviewAt),
        'last_reviewed_at': _dateTimeToSeconds(state.lastReviewedAt),
        'streak': state.streak,
        'total_reviews': state.totalReviews,
        'fail_count': state.failCount,
        'interval': state.interval,
        'ease_factor': state.easeFactor,
        'stability': state.stability,
        'difficulty': state.difficulty,
      },
    );
  }

  Future<void> pushBookProgress({
    required BookProgress progress,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'book_progress',
      entityKey: progress.bookId,
      operation: operation,
      payload: {
        'book_id': progress.bookId,
        'total_words': progress.totalWords,
        'learned_count': progress.learnedCount,
        'mastered_count': progress.masteredCount,
        'ignored_count': progress.ignoredCount,
        'is_completed': progress.isCompleted,
        'current_sort_cursor': progress.currentSortCursor,
      },
    );
  }

  Future<void> pushWordFavorite({
    required WordFavorite favorite,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'word_favorite',
      entityKey: favorite.wordId,
      operation: operation,
      payload: {'word_id': favorite.wordId, 'book_id': favorite.bookId},
    );
  }

  Future<void> pushWordExampleFavorite({
    required WordExampleFavorite favorite,
    required String operation,
  }) {
    return _enqueueAndDispatch(
      entityType: 'word_example_favorite',
      entityKey: favorite.exampleId,
      operation: operation,
      payload: {'example_id': favorite.exampleId, 'word_id': favorite.wordId},
    );
  }

  Future<void> dispatchPendingForCurrentUser() async {
    final syncUserId = _currentSyncUserId;
    if (syncUserId == null) {
      return;
    }

    await _dispatchPending(syncUserId);
  }

  Future<void> syncDownForCurrentUser({required int localUserId}) async {
    final syncUserId = _currentSyncUserId;
    if (syncUserId == null) {
      logger.info('当前未登录 Supabase，跳过云端下行同步');
      return;
    }

    await _dispatchPending(syncUserId);

    final deviceId = await _ensureDeviceRegistered(syncUserId);
    var syncState =
        (await _syncStateRepo.getState(syncUserId) ??
                SyncState(syncUserId: syncUserId))
            .copyWith(deviceId: deviceId, updatedAt: _nowSeconds());
    await _syncStateRepo.upsertState(syncState);

    if (syncState.lastPulledSeq <= 0) {
      syncState = await _bootstrapRemoteSnapshot(
        syncState: syncState,
        deviceId: deviceId,
        localUserId: localUserId,
      );
    }

    await _pullRemoteEvents(
      syncState: syncState,
      deviceId: deviceId,
      localUserId: localUserId,
    );

    _homeSummaryInvalidation.markStale();
  }

  Future<void> _enqueueAndDispatch({
    required String entityType,
    required String entityKey,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final syncUserId = _currentSyncUserId;
    if (syncUserId == null) {
      logger.info('当前未登录 Supabase，跳过云端同步: $entityType/$entityKey');
      return;
    }

    final now = _nowSeconds();
    final item = SyncOutboxItem(
      id: 0,
      syncUserId: syncUserId,
      mutationId: _uuid.v4(),
      entityType: entityType,
      entityKey: entityKey,
      operation: operation,
      payload: jsonEncode(payload),
      createdAt: now,
      updatedAt: now,
    );

    await _outboxRepo.enqueue(item);
    await _dispatchPending(syncUserId);
  }

  Future<void> _dispatchPending(String syncUserId) async {
    if (_dispatchInFlight != null) {
      _dispatchQueued = true;
      await _dispatchInFlight;
      return;
    }

    final completer = Completer<void>();
    _dispatchInFlight = completer.future;

    try {
      do {
        _dispatchQueued = false;
        await _dispatchPendingOnce(syncUserId);
      } while (_dispatchQueued);
      completer.complete();
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
      logger.error('同步 outbox 派发失败', e, stackTrace);
      rethrow;
    } finally {
      _dispatchInFlight = null;
    }
  }

  Future<void> _dispatchPendingOnce(String syncUserId) async {
    final items = await _outboxRepo.getDispatchableItems(syncUserId, limit: 50);
    if (items.isEmpty) {
      return;
    }

    final deviceId = await _ensureDeviceRegistered(syncUserId);
    final now = _nowSeconds();
    final existingState = await _syncStateRepo.getState(syncUserId);
    final nextState = (existingState ?? SyncState(syncUserId: syncUserId))
        .copyWith(deviceId: deviceId, lastPushAt: now, updatedAt: now);
    await _syncStateRepo.upsertState(nextState);

    await _outboxRepo.markItemsSyncing(items.map((item) => item.id).toList());

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.syncPush,
        data: {
          'device_id': deviceId,
          'mutations': items.map(_toSyncMutation).toList(),
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
      final ackedMutations =
          (data['acked_mutations'] as List<dynamic>? ?? const [])
              .map((entry) => entry as Map<String, dynamic>)
              .toList();
      final conflicts = (data['conflicts'] as List<dynamic>? ?? const [])
          .map((entry) => entry as Map<String, dynamic>)
          .toList();

      final ackedIds = ackedMutations
          .map((entry) => entry['mutation_id'] as String?)
          .whereType<String>()
          .toSet();
      final conflictIds = conflicts
          .map((entry) => entry['mutation_id'] as String?)
          .whereType<String>()
          .toSet();

      final deleteIds = items
          .where(
            (item) =>
                ackedIds.contains(item.mutationId) ||
                conflictIds.contains(item.mutationId),
          )
          .map((item) => item.id)
          .toList();
      if (deleteIds.isNotEmpty) {
        await _outboxRepo.deleteItems(deleteIds);
      }

      final unresolved = items.where(
        (item) =>
            !ackedIds.contains(item.mutationId) &&
            !conflictIds.contains(item.mutationId),
      );
      for (final item in unresolved) {
        await _outboxRepo.markItemFailed(
          item.id,
          lastError: 'SYNC_PUSH_MISSING_ACK',
          nextRetryAt: now + _retryDelaySeconds,
        );
      }

      if (conflicts.isNotEmpty) {
        logger.warning('检测到云端同步冲突 ${conflicts.length} 条，当前已停止重试这些 mutation');
      }

      await _syncStateRepo.upsertState(
        nextState.copyWith(
          lastSuccessAt: _nowSeconds(),
          updatedAt: _nowSeconds(),
        ),
      );
    } catch (e) {
      for (final item in items) {
        await _outboxRepo.markItemFailed(
          item.id,
          lastError: e.toString(),
          nextRetryAt: _nowSeconds() + _retryDelaySeconds,
        );
      }
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> dispatchPendingForTesting(String syncUserId) async {
    await _dispatchPending(syncUserId);
  }

  Future<String> _ensureDeviceRegistered(String syncUserId) async {
    final existing = await _syncStateRepo.getState(syncUserId);
    final existingDeviceId = existing?.deviceId;
    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      return existingDeviceId;
    }

    final deviceId = _uuid.v4();
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.syncRegisterDevice,
      data: {'device_id': deviceId, 'platform': _platformName()},
    );

    final now = _nowSeconds();
    await _syncStateRepo.upsertState(
      (existing ?? SyncState(syncUserId: syncUserId)).copyWith(
        deviceId: deviceId,
        updatedAt: now,
      ),
    );
    return deviceId;
  }

  Future<SyncState> _bootstrapRemoteSnapshot({
    required SyncState syncState,
    required String deviceId,
    required int localUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.syncBootstrap,
      queryParameters: {'device_id': deviceId, 'limit': 500},
    );

    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};
    final remoteKanaStates = _asMapList(data['kana_states']);
    final shouldUploadLocalKanaStates = remoteKanaStates.isEmpty;

    await _replaceLocalSnapshot(
      localUserId: localUserId,
      profile: data['profile'],
      wordStates: data['word_states'],
      kanaStates: remoteKanaStates,
      grammarStates: data['grammar_states'],
      bookProgress: data['book_progress'],
      wordFavorites: data['word_favorites'],
      wordExampleFavorites: data['word_example_favorites'],
      preserveLocalKanaStates: shouldUploadLocalKanaStates,
    );

    final now = _nowSeconds();
    final nextState = syncState.copyWith(
      lastPulledSeq: _toInt(meta['next_cursor']) ?? syncState.lastPulledSeq,
      lastSuccessAt: now,
      updatedAt: now,
    );
    await _syncStateRepo.upsertState(nextState);

    if (shouldUploadLocalKanaStates) {
      await _pushBootstrapLocalKanaStates(
        syncUserId: syncState.syncUserId,
        localUserId: localUserId,
      );
    }

    return nextState;
  }

  Future<void> _pullRemoteEvents({
    required SyncState syncState,
    required String deviceId,
    required int localUserId,
  }) async {
    var cursor = syncState.lastPulledSeq;
    var hasMore = true;

    while (hasMore) {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.syncPull,
        queryParameters: {
          'device_id': deviceId,
          'after_seq': cursor,
          'limit': 500,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final events = (body['data'] as List<dynamic>? ?? const []);
      final meta = body['meta'] as Map<String, dynamic>? ?? const {};

      for (final event in events) {
        final map = Map<String, dynamic>.from(event as Map);
        await _applyRemoteEvent(localUserId, map);
      }

      cursor = _toInt(meta['next_cursor']) ?? cursor;
      hasMore = meta['has_more'] == true;
      await _syncStateRepo.upsertState(
        syncState.copyWith(
          lastPulledSeq: cursor,
          lastSuccessAt: _nowSeconds(),
          updatedAt: _nowSeconds(),
        ),
      );

      if (events.isEmpty) {
        break;
      }
    }
  }

  Future<void> _replaceLocalSnapshot({
    required int localUserId,
    required Object? profile,
    required Object? wordStates,
    required Object? kanaStates,
    required Object? grammarStates,
    required Object? bookProgress,
    required Object? wordFavorites,
    required Object? wordExampleFavorites,
    bool preserveLocalKanaStates = false,
  }) async {
    await _studyWordRepo.deleteAllByUser(localUserId);
    if (!preserveLocalKanaStates) {
      await _kanaRepo.deleteKanaLearningStatesByUser(localUserId);
    }
    await _grammarRepo.deleteAllByUser(localUserId);
    await _bookProgressRepo.deleteAllByUser(localUserId);
    await _wordFavoriteRepo.deleteAllByUser(localUserId);
    await _wordExampleFavoriteRepo.deleteAllByUser(localUserId);

    await _applyProfile(localUserId, profile);

    for (final row in _asMapList(wordStates)) {
      await _studyWordRepo.saveStudyWord(
        _studyWordFromRemote(localUserId, row),
      );
    }
    if (!preserveLocalKanaStates) {
      for (final row in _asMapList(kanaStates)) {
        await _kanaRepo.upsertKanaLearningState(
          _kanaStateFromRemote(localUserId, row),
        );
      }
    }
    for (final row in _asMapList(grammarStates)) {
      await _grammarRepo.saveStudyGrammar(
        _grammarStateFromRemote(localUserId, row),
      );
    }
    for (final row in _asMapList(bookProgress)) {
      await _bookProgressRepo.upsertProgress(
        _bookProgressFromRemote(localUserId, row),
      );
    }
    for (final row in _asMapList(wordFavorites)) {
      await _wordFavoriteRepo.saveFavorite(
        _wordFavoriteFromRemote(localUserId, row),
      );
    }
    for (final row in _asMapList(wordExampleFavorites)) {
      await _wordExampleFavoriteRepo.saveFavorite(
        _wordExampleFavoriteFromRemote(localUserId, row),
      );
    }
  }

  Future<void> _pushBootstrapLocalKanaStates({
    required String syncUserId,
    required int localUserId,
  }) async {
    final localKanaStates = await _kanaRepo.getAllKanaLearningStates(
      localUserId,
    );
    if (localKanaStates.isEmpty) {
      return;
    }

    final now = _nowSeconds();
    for (final state in localKanaStates) {
      await _outboxRepo.enqueue(
        SyncOutboxItem(
          id: 0,
          syncUserId: syncUserId,
          mutationId: _uuid.v4(),
          entityType: 'kana_state',
          entityKey: state.kanaId.toString(),
          operation: 'upsert',
          payload: jsonEncode(_kanaStatePayload(state)),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    logger.info('首登同步检测到云端无 kana 状态，已加入待同步队列 ${localKanaStates.length} 条');
    unawaited(
      _dispatchBootstrapLocalKanaStates(
        syncUserId: syncUserId,
        count: localKanaStates.length,
      ),
    );
  }

  Future<void> _dispatchBootstrapLocalKanaStates({
    required String syncUserId,
    required int count,
  }) async {
    try {
      await _dispatchPendingOnce(syncUserId);
    } catch (e, stackTrace) {
      logger.warning('首登 kana 状态已写入本地 outbox，云端同步稍后重试: $count 条');
      logger.error('首登 kana 状态回推失败', e, stackTrace);
    }
  }

  Future<void> _applyRemoteEvent(
    int localUserId,
    Map<String, dynamic> event,
  ) async {
    final entityType = event['entity_type'] as String?;
    final operation = event['operation'] as String? ?? 'upsert';
    final payload = Map<String, dynamic>.from(
      (event['payload'] as Map?) ?? const <String, dynamic>{},
    );

    switch (entityType) {
      case 'profile':
        await _applyProfile(localUserId, payload);
        return;
      case 'word_state':
        if (operation == 'delete' || payload['deleted'] == true) {
          final wordId = payload['word_id'] as String?;
          final bookId = payload['book_id'] as String?;
          if (wordId != null && bookId != null) {
            await _studyWordRepo.deleteStudyWordByUniqueKey(
              localUserId,
              wordId,
              bookId,
            );
          }
          return;
        }
        await _studyWordRepo.saveStudyWord(
          _studyWordFromRemote(localUserId, payload),
        );
        return;
      case 'kana_state':
        if (operation == 'delete' || payload['deleted'] == true) {
          final kanaId = _toInt(payload['kana_id']);
          if (kanaId != null) {
            await _kanaRepo.deleteKanaLearningState(localUserId, kanaId);
          }
          return;
        }
        await _kanaRepo.upsertKanaLearningState(
          _kanaStateFromRemote(localUserId, payload),
        );
        return;
      case 'grammar_state':
        if (operation == 'delete' || payload['deleted'] == true) {
          final grammarId = _toInt(payload['grammar_id']);
          if (grammarId != null) {
            await _grammarRepo.deleteStudyGrammar(localUserId, grammarId);
          }
          return;
        }
        await _grammarRepo.saveStudyGrammar(
          _grammarStateFromRemote(localUserId, payload),
        );
        return;
      case 'book_progress':
        if (operation == 'delete' || payload['deleted'] == true) {
          final bookId = payload['book_id'] as String?;
          if (bookId != null) {
            await _bookProgressRepo.deleteProgress(localUserId, bookId);
          }
          return;
        }
        await _bookProgressRepo.upsertProgress(
          _bookProgressFromRemote(localUserId, payload),
        );
        return;
      case 'word_favorite':
        if (operation == 'delete' || payload['deleted'] == true) {
          final wordId = payload['word_id'] as String?;
          if (wordId != null) {
            await _wordFavoriteRepo.deleteFavorite(localUserId, wordId);
          }
          return;
        }
        await _wordFavoriteRepo.saveFavorite(
          _wordFavoriteFromRemote(localUserId, payload),
        );
        return;
      case 'word_example_favorite':
        if (operation == 'delete' || payload['deleted'] == true) {
          final exampleId = payload['example_id'] as String?;
          if (exampleId != null) {
            await _wordExampleFavoriteRepo.deleteFavorite(
              localUserId,
              exampleId,
            );
          }
          return;
        }
        await _wordExampleFavoriteRepo.saveFavorite(
          _wordExampleFavoriteFromRemote(localUserId, payload),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _applyProfile(int localUserId, Object? rawProfile) async {
    if (rawProfile is! Map) {
      return;
    }

    final profile = Map<String, dynamic>.from(rawProfile);
    final existing = await _userRepo.getUserById(localUserId);
    if (existing == null) {
      return;
    }

    final updated = existing.copyWith(
      email: profile['email'] as String? ?? existing.email,
      nickname: profile['display_name'] as String? ?? existing.nickname,
      avatarUrl: profile['avatar_url'] as String? ?? existing.avatarUrl,
      settings: profile['settings'] == null
          ? existing.settings
          : jsonEncode(profile['settings']),
      locale: profile['locale'] as String? ?? existing.locale,
      timezone: profile['timezone'] as String? ?? existing.timezone,
      onboardingCompleted: _toBool(profile['onboarding_completed'])
          ? 1
          : existing.onboardingCompleted,
      proStatus: _toInt(profile['pro_status']) ?? existing.proStatus,
      updatedAt:
          (_parseDateTime(profile['updated_at']) ?? DateTime.now())
              .millisecondsSinceEpoch ~/
          1000,
    );
    await _userRepo.updateUser(updated);
  }

  StudyWord _studyWordFromRemote(int localUserId, Map<String, dynamic> map) {
    final createdAt = _parseDateTime(map['created_at']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updated_at']) ?? createdAt;
    return StudyWord(
      id: 0,
      userId: localUserId,
      wordId: map['word_id'] as String,
      bookId: map['book_id'] as String,
      userState: LearningStatus.fromValue(_toInt(map['user_state']) ?? 0),
      nextReviewAt: _parseDateTime(map['next_review_at']),
      lastReviewedAt: _parseDateTime(map['last_reviewed_at']),
      firstLearnedAt: _parseDateTime(map['first_learned_at']),
      interval: _toInt(map['interval']),
      easeFactor: _toDouble(map['ease_factor']),
      stability: _toDouble(map['stability']),
      difficulty: _toDouble(map['difficulty']),
      streak: _toInt(map['streak']) ?? 0,
      totalReviews: _toInt(map['total_reviews']) ?? 0,
      failCount: _toInt(map['fail_count']) ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  KanaLearningState _kanaStateFromRemote(
    int localUserId,
    Map<String, dynamic> map,
  ) {
    return KanaLearningState(
      id: 0,
      userId: localUserId,
      kanaId: _toInt(map['kana_id']) ?? 0,
      learningStatus: LearningStatus.fromValue(
        _toInt(map['learning_status']) ?? LearningStatus.learning.value,
      ),
      nextReviewAt: _toInt(map['next_review_at']),
      lastReviewedAt: _toInt(map['last_reviewed_at']),
      streak: _toInt(map['streak']) ?? 0,
      totalReviews: _toInt(map['total_reviews']) ?? 0,
      failCount: _toInt(map['fail_count']) ?? 0,
      interval: _toDouble(map['interval']) ?? 0,
      easeFactor: _toDouble(map['ease_factor']) ?? 2.5,
      stability: _toDouble(map['stability']) ?? 0,
      difficulty: _toDouble(map['difficulty']) ?? 0,
      createdAt:
          (_parseDateTime(map['created_at']) ?? DateTime.now())
              .millisecondsSinceEpoch ~/
          1000,
      updatedAt:
          (_parseDateTime(map['updated_at']) ?? DateTime.now())
              .millisecondsSinceEpoch ~/
          1000,
    );
  }

  StudyGrammar _grammarStateFromRemote(
    int localUserId,
    Map<String, dynamic> map,
  ) {
    final createdAt = _parseDateTime(map['created_at']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updated_at']) ?? createdAt;
    return StudyGrammar(
      id: 0,
      userId: localUserId,
      grammarId: _toInt(map['grammar_id']) ?? 0,
      learningStatus: _toInt(map['learning_status']) ?? 0,
      nextReviewAt: _parseDateTime(map['next_review_at']),
      lastReviewedAt: _parseDateTime(map['last_reviewed_at']),
      streak: _toInt(map['streak']) ?? 0,
      totalReviews: _toInt(map['total_reviews']) ?? 0,
      failCount: _toInt(map['fail_count']) ?? 0,
      interval: _toDouble(map['interval']) ?? 0,
      easeFactor: _toDouble(map['ease_factor']) ?? 2.5,
      stability: _toDouble(map['stability']) ?? 0,
      difficulty: _toDouble(map['difficulty']) ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  BookProgress _bookProgressFromRemote(
    int localUserId,
    Map<String, dynamic> map,
  ) {
    final createdAt = _parseDateTime(map['created_at']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updated_at']) ?? createdAt;
    return BookProgress(
      id: 0,
      userId: localUserId,
      bookId: map['book_id'] as String,
      totalWords: _toInt(map['total_words']) ?? 0,
      learnedCount: _toInt(map['learned_count']) ?? 0,
      masteredCount: _toInt(map['mastered_count']) ?? 0,
      ignoredCount: _toInt(map['ignored_count']) ?? 0,
      isCompleted: _toBool(map['is_completed']),
      currentSortCursor: _toInt(map['current_sort_cursor']) ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  WordFavorite _wordFavoriteFromRemote(
    int localUserId,
    Map<String, dynamic> map,
  ) {
    final createdAt = _parseDateTime(map['created_at']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updated_at']) ?? createdAt;
    return WordFavorite(
      id: 0,
      userId: localUserId,
      wordId: map['word_id'] as String,
      bookId: map['book_id'] as String,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  WordExampleFavorite _wordExampleFavoriteFromRemote(
    int localUserId,
    Map<String, dynamic> map,
  ) {
    final createdAt = _parseDateTime(map['created_at']) ?? DateTime.now();
    final updatedAt = _parseDateTime(map['updated_at']) ?? createdAt;
    return WordExampleFavorite(
      id: 0,
      userId: localUserId,
      exampleId: map['example_id'] as String,
      wordId: map['word_id'] as String,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool _toBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    return false;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int || value is num) {
      return DateTime.fromMillisecondsSinceEpoch(_toInt(value)! * 1000);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _toSyncMutation(SyncOutboxItem item) {
    return {
      'mutation_id': item.mutationId,
      'entity_type': item.entityType,
      'entity_key': item.entityKey,
      'operation': item.operation,
      'payload': jsonDecode(item.payload) as Map<String, dynamic>,
      if (item.baseVersion != null) 'base_version': item.baseVersion,
    };
  }

  Map<String, dynamic> _kanaStatePayload(KanaLearningState state) {
    return {
      'kana_id': state.kanaId,
      'learning_status': state.learningStatus.value,
      'next_review_at': state.nextReviewAt,
      'last_reviewed_at': state.lastReviewedAt,
      'streak': state.streak,
      'total_reviews': state.totalReviews,
      'fail_count': state.failCount,
      'interval': state.interval,
      'ease_factor': state.easeFactor,
      'stability': state.stability,
      'difficulty': state.difficulty,
    };
  }

  String? get _currentSyncUserId =>
      _currentSyncUserIdGetter?.call() ??
      Supabase.instance.client.auth.currentUser?.id;

  static int? _dateTimeToSeconds(DateTime? value) {
    return value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
