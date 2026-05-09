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
import '../models/sync_state.dart';
import '../models/word_example_favorite.dart';
import '../models/word_favorite.dart';
import '../queries/active_user_query_provider.dart';
import '../repositories/book_progress_repository.dart';
import '../repositories/book_progress_repository_provider.dart';
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

/// 当服务端报告当前设备已被其他设备接管时变为 true。
/// UI 层可监听此 provider，在为 true 时提示用户"账号已在其他设备登录"。
final syncDisplacedProvider = NotifierProvider<SyncDisplacedNotifier, bool>(
  SyncDisplacedNotifier.new,
);

class SyncDisplacedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setDisplaced() => state = true;
  void reset() => state = false;
}

class SyncRemoteCommand {
  SyncRemoteCommand(
    this.ref, {
    Dio? dio,
    String? Function()? currentSyncUserIdGetter,
  }) : _dio = dio ?? DioClient.instance.dio,
       _currentSyncUserIdGetter = currentSyncUserIdGetter;

  static const _uuid = Uuid();

  final Ref ref;
  final Dio _dio;
  final String? Function()? _currentSyncUserIdGetter;

  /// 防抖计时器：最多每 5 秒触发一次 checkpoint
  Timer? _debounceTimer;

  SyncStateRepository get _syncStateRepo =>
      ref.read(syncStateRepositoryProvider);
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

  // ---------------------------------------------------------------------------
  // 公开 API
  // ---------------------------------------------------------------------------

  /// 防抖调度 checkpoint（5 秒后触发）。
  /// 在各业务 Command 保存本地数据后调用，不需要传任何参数。
  void scheduleCheckpoint() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_runScheduledCheckpoint());
    });
  }

  /// 立即执行完整的快照 checkpoint（push + pull）。
  /// 由 SyncSchedulerCommand 在定时/切回前台时调用。
  /// 登录/bootstrap 场景：force_takeover=true，强制接管活跃设备槽。
  Future<void> checkpointForCurrentUser({required int localUserId}) async {
    final syncUserId = _currentSyncUserId;
    if (syncUserId == null) {
      logger.info('当前未登录 Supabase，跳过 checkpoint');
      return;
    }
    await _doCheckpoint(
      syncUserId: syncUserId,
      localUserId: localUserId,
      forceTakeover: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  Future<void> _runScheduledCheckpoint() async {
    final syncUserId = _currentSyncUserId;
    if (syncUserId == null) return;

    // 通过 ActiveUserQuery 获取本地 userId（与调度器保持一致）
    final localUserId = await ref
        .read(activeUserQueryProvider)
        .getActiveUserId();
    if (localUserId == null) return;

    try {
      await _doCheckpoint(
        syncUserId: syncUserId,
        localUserId: localUserId,
        forceTakeover: false,
      );
    } catch (e, stackTrace) {
      logger.error('[SyncRemote] 防抖 checkpoint 失败', e, stackTrace);
    }
  }

  Future<void> _doCheckpoint({
    required String syncUserId,
    required int localUserId,
    required bool forceTakeover,
  }) async {
    // 1. 确定 deviceId
    final deviceId = await _ensureDeviceId(syncUserId);

    // 2. 构建本地快照
    final snapshot = await _buildLocalSnapshot(localUserId);

    // 3. 调用 API
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.syncCheckpoint,
      data: {
        'device_id': deviceId,
        'platform': _platformName(),
        'force_takeover': forceTakeover,
        'snapshot': snapshot,
      },
    );

    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};

    // 4. 若服务端报告本设备已被踢下线，停止后台同步并通知 UI
    final displaced = meta['displaced'] == true;
    if (displaced) {
      _debounceTimer?.cancel();
      ref.read(syncDisplacedProvider.notifier).setDisplaced();
      logger.info('[SyncRemote] 已被其他设备接管，停止后台同步');
      return;
    }

    // 5. 用服务端完整状态覆盖本地
    await _replaceLocalSnapshot(
      localUserId: localUserId,
      profile: data['profile'],
      wordStates: data['word_states'],
      kanaStates: data['kana_states'],
      grammarStates: data['grammar_states'],
      bookProgress: data['book_progress'],
      wordFavorites: data['word_favorites'],
      wordExampleFavorites: data['word_example_favorites'],
    );

    // 6. 更新 SyncState
    final now = _nowSeconds();
    final existing = await _syncStateRepo.getState(syncUserId);
    await _syncStateRepo.upsertState(
      (existing ?? SyncState(syncUserId: syncUserId)).copyWith(
        deviceId: deviceId,
        lastPulledSeq: 1, // >0 表示"至少完成过一次 checkpoint"
        lastSuccessAt: now,
        updatedAt: now,
      ),
    );

    // 7. 若服务端报告设备切换，重置 displaced 状态并记录日志
    final tookOver = meta['took_over'] == true;
    if (tookOver) {
      ref.read(syncDisplacedProvider.notifier).reset();
      logger.info('[SyncRemote] 设备切换：已接管为活跃设备');
    }

    _homeSummaryInvalidation.markStale();
  }

  Future<String> _ensureDeviceId(String syncUserId) async {
    final existing = await _syncStateRepo.getState(syncUserId);
    final existingDeviceId = existing?.deviceId;
    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      return existingDeviceId;
    }
    final deviceId = _uuid.v4();
    final now = _nowSeconds();
    await _syncStateRepo.upsertState(
      (existing ?? SyncState(syncUserId: syncUserId)).copyWith(
        deviceId: deviceId,
        updatedAt: now,
      ),
    );
    return deviceId;
  }

  /// 将本地数据库内容序列化为快照 payload。
  /// 所有时间戳字段以 epoch seconds (int) 传给服务端。
  Future<Map<String, dynamic>> _buildLocalSnapshot(int localUserId) async {
    final wordStates = await _studyWordRepo.getAllByUser(localUserId);
    final kanaStates = await _kanaRepo.getAllKanaLearningStates(localUserId);
    final grammarStates = await _grammarRepo.getAllByUser(localUserId);
    final bookProgressList = await _bookProgressRepo.getAllByUser(localUserId);
    final wordFavorites = await _wordFavoriteRepo.getAllByUser(localUserId);
    final wordExFavorites = await _wordExampleFavoriteRepo.getAllByUser(
      localUserId,
    );

    return {
      'word_states': wordStates
          .map(
            (s) => {
              'word_id': s.wordId,
              'book_id': s.bookId,
              'user_state': s.userState.value,
              'next_review_at': _dateTimeToSeconds(s.nextReviewAt),
              'last_reviewed_at': _dateTimeToSeconds(s.lastReviewedAt),
              'first_learned_at': _dateTimeToSeconds(s.firstLearnedAt),
              'interval': s.interval,
              'ease_factor': s.easeFactor,
              'stability': s.stability,
              'difficulty': s.difficulty,
              'streak': s.streak,
              'total_reviews': s.totalReviews,
              'fail_count': s.failCount,
              'updated_at': s.updatedAt.millisecondsSinceEpoch ~/ 1000,
            },
          )
          .toList(),
      'kana_states': kanaStates
          .map(
            (s) => {
              'kana_id': s.kanaId,
              'learning_status': s.learningStatus.value,
              'next_review_at': s.nextReviewAt,
              'last_reviewed_at': s.lastReviewedAt,
              'streak': s.streak,
              'total_reviews': s.totalReviews,
              'fail_count': s.failCount,
              'interval': s.interval,
              'ease_factor': s.easeFactor,
              'stability': s.stability,
              'difficulty': s.difficulty,
              'updated_at': s.updatedAt,
            },
          )
          .toList(),
      'grammar_states': grammarStates
          .map(
            (s) => {
              'grammar_id': s.grammarId,
              'learning_status': s.learningStatus,
              'next_review_at': _dateTimeToSeconds(s.nextReviewAt),
              'last_reviewed_at': _dateTimeToSeconds(s.lastReviewedAt),
              'streak': s.streak,
              'total_reviews': s.totalReviews,
              'fail_count': s.failCount,
              'interval': s.interval,
              'ease_factor': s.easeFactor,
              'stability': s.stability,
              'difficulty': s.difficulty,
              'updated_at': s.updatedAt.millisecondsSinceEpoch ~/ 1000,
            },
          )
          .toList(),
      'book_progress': bookProgressList
          .map(
            (s) => {
              'book_id': s.bookId,
              'total_words': s.totalWords,
              'learned_count': s.learnedCount,
              'mastered_count': s.masteredCount,
              'ignored_count': s.ignoredCount,
              'is_completed': s.isCompleted,
              'current_sort_cursor': s.currentSortCursor,
              'updated_at': s.updatedAt.millisecondsSinceEpoch ~/ 1000,
            },
          )
          .toList(),
      'word_favorites': wordFavorites
          .map(
            (s) => {
              'word_id': s.wordId,
              'book_id': s.bookId,
              'updated_at': s.updatedAt.millisecondsSinceEpoch ~/ 1000,
            },
          )
          .toList(),
      'word_example_favorites': wordExFavorites
          .map(
            (s) => {
              'example_id': s.exampleId,
              'word_id': s.wordId,
              'updated_at': s.updatedAt.millisecondsSinceEpoch ~/ 1000,
            },
          )
          .toList(),
    };
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
  }) async {
    await _studyWordRepo.deleteAllByUser(localUserId);
    await _kanaRepo.deleteKanaLearningStatesByUser(localUserId);
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
    for (final row in _asMapList(kanaStates)) {
      await _kanaRepo.upsertKanaLearningState(
        _kanaStateFromRemote(localUserId, row),
      );
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

  // ---------------------------------------------------------------------------
  // Remote → Local 映射
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

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
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is int || value is num) {
      return DateTime.fromMillisecondsSinceEpoch(_toInt(value)! * 1000);
    }
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static int? _dateTimeToSeconds(DateTime? value) {
    return value == null ? null : value.millisecondsSinceEpoch ~/ 1000;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  String? get _currentSyncUserId =>
      _currentSyncUserIdGetter?.call() ??
      Supabase.instance.client.auth.currentUser?.id;

  static String _platformName() {
    if (kIsWeb) return 'web';
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
