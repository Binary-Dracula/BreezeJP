import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/log_formatter.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

/// WordLearningState 与 StudyWord 使用同一数据结构，避免重复模型。
typedef WordLearningState = StudyWord;

final wordCommandProvider = Provider<WordCommand>((ref) {
  return WordCommand(ref);
});

/// Word 行为命令层（学习状态写入 / 生命周期控制）
///
/// 2.0 变更：
/// - wordId 类型 int → String（UUID）
/// - 移除 StudyLogCommand / DailyStatCommand 依赖
/// - 新增 sourceBookId / firstLearnedAt / introducedAt 写入
class WordCommand {
  WordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);

  /// 获取或创建学习状态（首次展示：seen）。
  Future<WordLearningState> getOrCreateLearningState(
    int userId,
    String wordId,
  ) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId);
      if (existing != null) return existing;

      final now = DateTime.now();
      final state = StudyWord(
        id: 0,
        userId: userId,
        wordId: wordId,
        userState: LearningStatus.seen,
        nextReviewAt: null,
        lastReviewedAt: null,
        interval: 0,
        easeFactor: 2.5,
        stability: 0,
        difficulty: 0,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final id = await _repo.createStudyWord(state);
      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: 'null',
        toState: 'seen',
        reason: 'ensure_seen',
      );
      return state.copyWith(id: id);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 确保单词存在 seen 状态（幂等）
  Future<void> ensureWordSeen(int userId, String wordId) async {
    final existing = await _repo.getStudyWord(userId, wordId);
    if (existing != null) return;

    final now = DateTime.now();

    await _repo.createStudyWordIgnoreConflict(
      StudyWord(
        id: 0,
        userId: userId,
        wordId: wordId,
        userState: LearningStatus.seen,
        nextReviewAt: null,
        lastReviewedAt: null,
        interval: null,
        easeFactor: null,
        stability: null,
        difficulty: null,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    logger.stateChange(
      scope: 'word',
      userId: userId,
      itemId: wordId,
      fromState: 'null',
      toState: 'seen',
      reason: 'initial_exposure',
    );
  }

  /// 加入复习（seen / null → learning + firstLearnedAt）
  Future<void> addWordToReview(
    int userId,
    String wordId, {
    String? sourceBookId,
  }) async {
    await _enterLearningStateOnly(
      userId,
      wordId,
      reason: 'add_to_review',
      sourceBookId: sourceBookId,
      markFirstLearned: true,
    );
  }

  /// 进入学习阶段（仅状态迁移，不写 firstLearnedAt）
  Future<void> enterWordLearningIfNeeded(int userId, String wordId) async {
    await _enterLearningStateOnly(userId, wordId, reason: 'enter_learning');
  }

  /// 记录一次复习并更新 SRS 状态。
  Future<void> onWordReviewed({
    required int userId,
    required String wordId,
    required ReviewRating rating,
    AlgorithmType? algorithmType,
  }) async {
    final existing = await _repo.getStudyWord(userId, wordId);
    if (existing == null) {
      logger.warning('单词学习状态不存在: userId=$userId, wordId=$wordId');
      return;
    }
    if (existing.userState != LearningStatus.learning) {
      logger.warning(
        '[WordState] ignore review: wordId=$wordId userId=$userId state=${existing.userState.name}',
      );
      return;
    }

    final now = DateTime.now();
    final resolvedAlgorithm =
        algorithmType ?? _algorithmService.defaultAlgorithm;
    final lastReviewedAt = existing.lastReviewedAt;
    final elapsedSeconds = lastReviewedAt == null
        ? 0
        : now.difference(lastReviewedAt).inSeconds;
    final double elapsedDays = elapsedSeconds <= 0
        ? 0.0
        : elapsedSeconds / 86400.0;
    final input = SRSInput(
      interval: (existing.interval ?? 0).toDouble(),
      easeFactor: existing.easeFactor ?? AppConstants.defaultEaseFactor,
      stability: existing.stability ?? 0,
      difficulty: existing.difficulty ?? 0,
      reviews: existing.totalReviews,
      lapses: existing.failCount,
      rating: rating,
      elapsedDays: elapsedDays,
    );
    final output = _algorithmService.calculate(
      algorithmType: resolvedAlgorithm,
      input: input,
    );

    final totalReviews = existing.totalReviews + 1;
    final failCount = existing.failCount + (rating.isCorrect ? 0 : 1);
    final streak = rating.isCorrect ? existing.streak + 1 : 0;

    final updated = existing.copyWith(
      nextReviewAt: output.nextReviewAt,
      lastReviewedAt: now,
      interval: output.interval.round(),
      easeFactor: output.easeFactor,
      stability: output.stability,
      difficulty: output.difficulty,
      streak: streak,
      totalReviews: totalReviews,
      failCount: failCount,
      updatedAt: now,
    );

    await _repo.updateStudyWord(updated);
    logger.srsUpdate(
      scope: 'word',
      userId: userId,
      itemId: wordId,
      rating: rating,
      algorithmType: resolvedAlgorithm,
      before: _srsSnapshot(existing),
      after: _srsSnapshot(updated),
    );
  }

  /// 进入学习阶段（仅状态迁移）
  Future<void> _enterLearningStateOnly(
    int userId,
    String wordId, {
    required String reason,
    String? sourceBookId,
    bool markFirstLearned = false,
  }) async {
    final existing = await _repo.getStudyWord(userId, wordId);

    final delayMinutes = ref.read(firstReviewIntervalProvider);
    final now = DateTime.now();
    final firstReviewTime = now.add(Duration(minutes: delayMinutes));

    final output = SRSOutput(
      nextReviewAt: firstReviewTime,
      interval: 0,
      easeFactor: AppConstants.defaultEaseFactor,
      stability: 0,
      difficulty: 0,
    );

    // ========= 情况 1：不存在记录，auto-create learning =========
    if (existing == null) {
      final state = StudyWord(
        id: 0,
        userId: userId,
        wordId: wordId,
        userState: LearningStatus.learning,
        nextReviewAt: output.nextReviewAt,
        lastReviewedAt: null,
        firstLearnedAt: markFirstLearned ? now : null,
        introducedAt: now,
        sourceBookId: sourceBookId,
        interval: output.interval.round(),
        easeFactor: output.easeFactor,
        stability: output.stability,
        difficulty: output.difficulty,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final insertedRowId = await _repo.createStudyWordIgnoreConflict(state);

      if (insertedRowId > 0) {
        logger.stateChange(
          scope: 'word',
          userId: userId,
          itemId: wordId,
          fromState: 'null',
          toState: 'learning',
          reason: reason,
        );
        return;
      }

      // 并发被抢先创建：fall through 更新
      final after = await _repo.getStudyWord(userId, wordId);
      if (after == null) return;

      if (after.userState != LearningStatus.learning) {
        await _repo.updateStudyWord(
          after.copyWith(
            userState: LearningStatus.learning,
            nextReviewAt: output.nextReviewAt,
            firstLearnedAt: markFirstLearned && after.firstLearnedAt == null
                ? now
                : null,
            sourceBookId: sourceBookId ?? after.sourceBookId,
            interval: output.interval.round(),
            easeFactor: output.easeFactor,
            stability: output.stability,
            difficulty: output.difficulty,
            updatedAt: now,
          ),
        );

        logger.stateChange(
          scope: 'word',
          userId: userId,
          itemId: wordId,
          fromState: after.userState.name,
          toState: 'learning',
          reason: reason,
        );
      }
      return;
    }

    // ========= 情况 2：已有记录 =========
    if (existing.userState != LearningStatus.learning) {
      await _repo.updateStudyWord(
        existing.copyWith(
          userState: LearningStatus.learning,
          nextReviewAt: output.nextReviewAt,
          firstLearnedAt: markFirstLearned && existing.firstLearnedAt == null
              ? now
              : null,
          sourceBookId: sourceBookId ?? existing.sourceBookId,
          interval: output.interval.round(),
          easeFactor: output.easeFactor,
          stability: output.stability,
          difficulty: output.difficulty,
          updatedAt: now,
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: existing.userState.name,
        toState: 'learning',
        reason: reason,
      );
    }
  }

  /// 标记单词为已掌握（learning -> mastered）
  Future<void> markWordAsMastered(int userId, String wordId) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId);
      if (existing == null) {
        logger.warning('单词学习状态不存在: userId=$userId, wordId=$wordId');
        return;
      }

      final now = DateTime.now();
      final updated = existing.copyWith(
        userState: LearningStatus.mastered,
        nextReviewAt: null,
        lastReviewedAt: now,
        updatedAt: now,
      );
      await _repo.updateStudyWord(updated);
      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: existing.userState.name,
        toState: 'mastered',
        reason: 'mark_mastered',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 恢复学习（mastered / ignored -> seen）
  Future<void> restoreToSeen({
    required int userId,
    required String wordId,
  }) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId);
      if (existing == null) {
        logger.warning('单词学习状态不存在: userId=$userId, wordId=$wordId');
        return;
      }

      if (existing.userState != LearningStatus.mastered &&
          existing.userState != LearningStatus.ignored) {
        return;
      }

      final now = DateTime.now();
      await _repo.updateStudyWord(
        existing.copyWith(
          userState: LearningStatus.seen,
          nextReviewAt: null,
          updatedAt: now,
        ),
      );

      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: existing.userState.name,
        toState: 'seen',
        reason: 'restore_seen',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 切换忽略状态
  Future<void> toggleWordIgnored(int userId, String wordId) async {
    try {
      final existing = await _repo.getStudyWord(userId, wordId);
      final now = DateTime.now();

      if (existing == null) {
        final state = StudyWord(
          id: 0,
          userId: userId,
          wordId: wordId,
          userState: LearningStatus.ignored,
          nextReviewAt: null,
          lastReviewedAt: null,
          interval: 0,
          easeFactor: 2.5,
          stability: 0,
          difficulty: 0,
          streak: 0,
          totalReviews: 0,
          failCount: 0,
          createdAt: now,
          updatedAt: now,
        );
        await _repo.createStudyWord(state);
        logger.stateChange(
          scope: 'word',
          userId: userId,
          itemId: wordId,
          fromState: 'null',
          toState: 'ignored',
          reason: 'toggle_ignored',
        );
        return;
      }

      if (existing.userState == LearningStatus.ignored) {
        await _repo.updateStudyWord(
          existing.copyWith(
            userState: LearningStatus.seen,
            nextReviewAt: null,
            updatedAt: now,
          ),
        );
        logger.stateChange(
          scope: 'word',
          userId: userId,
          itemId: wordId,
          fromState: 'ignored',
          toState: 'seen',
          reason: 'restore_seen',
        );
        return;
      }

      await _repo.updateStudyWord(
        existing.copyWith(
          userState: LearningStatus.ignored,
          nextReviewAt: null,
          updatedAt: now,
        ),
      );
      logger.stateChange(
        scope: 'word',
        userId: userId,
        itemId: wordId,
        fromState: existing.userState.name,
        toState: 'ignored',
        reason: 'toggle_ignored',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Map<String, dynamic> _srsSnapshot(StudyWord word) {
    return {
      'interval': word.interval,
      'ef': word.easeFactor,
      'stability': word.stability,
      'difficulty': word.difficulty,
      'nextReview': word.nextReviewAt != null
          ? LogFormatter.formatTimestamp(word.nextReviewAt!)
          : null,
      'lastReview': word.lastReviewedAt != null
          ? LogFormatter.formatTimestamp(word.lastReviewedAt!)
          : null,
      'streak': word.streak,
      'totalReviews': word.totalReviews,
      'failCount': word.failCount,
    };
  }
}
