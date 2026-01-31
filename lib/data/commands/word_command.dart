import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import 'daily_stat_command.dart';
import '../models/study_log.dart';
import '../models/study_word.dart';
import '../repositories/study_log_repository.dart';
import '../repositories/study_log_repository_provider.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';
import '../repositories/word_repository.dart';
import '../repositories/word_repository_provider.dart';
import 'study_log_command.dart';

/// WordLearningState 与 StudyWord 使用同一数据结构，避免重复模型。
typedef WordLearningState = StudyWord;

class _LearningEntryContext {
  const _LearningEntryContext({
    required this.now,
    required this.algorithmType,
    required this.output,
  });

  final DateTime now;
  final AlgorithmType algorithmType;
  final SRSOutput output;
}

final wordCommandProvider = Provider<WordCommand>((ref) {
  return WordCommand(ref);
});

/// Word 行为命令层（学习状态写入 / 生命周期控制）
class WordCommand {
  WordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);
  StudyLogRepository get _studyLogRepo => ref.read(studyLogRepositoryProvider);
  DailyStatCommand get _dailyStatCommand => ref.read(dailyStatCommandProvider);
  WordRepository get _wordRepo => ref.read(wordRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);
  StudyLogCommand get _studyLogCommand => ref.read(studyLogCommandProvider);

  /// 获取或创建学习状态（首次展示：seen）。
  ///
  /// 伪代码：
  /// getOrCreateLearningState(userId, wordId):
  ///   s = repo.get(userId, wordId)
  ///   if s != null: return s
  ///   now = now()
  ///   s = WordLearningState(
  ///         userId, wordId,
  ///         status=seen,
  ///         nextReviewAt=null,
  ///         srs_defaults...,
  ///         createdAt=now, updatedAt=now
  ///       )
  ///   id = repo.insert(s)
  ///   return s.withId(id)
  Future<WordLearningState> getOrCreateLearningState(
    int userId,
    int wordId,
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
      logger.info(
        '[WordState] wordId=$wordId userId=$userId null -> seen via ensure_seen',
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
  ///
  /// 规则（工程封板）：
  /// - 仅用于“用户第一次看到单词”
  /// - 若 study_words 不存在 → 创建 seen
  /// - 若已存在 → no-op
  /// - 严禁写 learning / firstLearn / daily_stats
  Future<void> ensureWordSeen(int userId, int wordId) async {
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

    logger.info(
      '[WordState] wordId=$wordId userId=$userId null -> seen (initial exposure)',
    );
  }

  /// ⚠️ firstLearn 写入约束（工程封板）
  ///
  /// 只允许在「用户点击加入复习」的行为路径调用：
  /// - addWordToReview（来自“加入复习”按钮）
  ///
  /// 明确禁止从以下路径调用：
  /// - quickMaster（直接已掌握）
  /// - markWordAsMastered
  /// - ignored / restore
  /// - 任意自动状态流转
  ///
  /// 判定规则：
  /// - 是否写 firstLearn 只依赖 study_logs 是否已存在
  /// - 严禁根据 study_words 状态推导
  Future<void> _logFirstLearnIfMissing({
    required int userId,
    required int wordId,
    required DateTime now,
    required AlgorithmType algorithmType,
    required SRSOutput output,
  }) async {
    final exists = await _studyLogRepo.existsFirstLearn(
      userId: userId,
      wordId: wordId,
    );
    if (exists) return;

    final log = StudyLog(
      id: 0,
      userId: userId,
      wordId: wordId,
      questionType: 'recall',
      logType: LogType.firstLearn,
      durationMs: 0,
      intervalAfter: output.interval,
      easeFactorAfter: output.easeFactor,
      nextReviewAtAfter: output.nextReviewAt,
      algorithm: AlgorithmService.getAlgorithmValue(algorithmType),
      fsrsStabilityAfter: output.stability,
      fsrsDifficultyAfter: output.difficulty,
      createdAt: now,
    );

    await _studyLogRepo.insert(log);
    await _dailyStatCommand.applyLearningDelta(
      userId: userId,
      learnedDelta: 1,
      reviewedDelta: 0,
    );
  }

  /// ⚠️ 工程封板说明：
  ///
  /// - firstLearn = 用户“点击加入复习”的行为事件
  /// - 本文件中，只有 addWordToReview() 允许写 firstLearn
  /// - 任何状态迁移 API（enter/restore 等）
  ///   都不允许隐式产生 firstLearn
  Future<void> addWordToReview(int userId, int wordId) async {
    final context = await _enterLearningStateOnly(userId, wordId);
    await _logFirstLearnIfMissing(
      userId: userId,
      wordId: wordId,
      now: context.now,
      algorithmType: context.algorithmType,
      output: context.output,
    );
  }

  /// 进入学习阶段（仅状态迁移，不写 firstLearn）
  Future<void> enterWordLearningIfNeeded(int userId, int wordId) async {
    await _enterLearningStateOnly(userId, wordId);
  }

  /// 记录一次复习并更新 SRS 状态。
  Future<void> onWordReviewed({
    required int userId,
    required int wordId,
    required ReviewRating rating,
    int durationMs = 0,
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

    await _studyLogCommand.logReview(
      userId: userId,
      wordId: wordId,
      rating: rating,
      durationMs: durationMs,
      intervalAfter: output.interval,
      easeFactorAfter: output.easeFactor,
      nextReviewAtAfter: output.nextReviewAt,
      algorithm: AlgorithmService.getAlgorithmValue(resolvedAlgorithm),
      fsrsStabilityAfter: output.stability,
      fsrsDifficultyAfter: output.difficulty,
    );
  }

  /// 进入学习阶段（仅状态迁移，不写 firstLearn）
  Future<_LearningEntryContext> _enterLearningStateOnly(
    int userId,
    int wordId,
  ) async {
    final existing = await _repo.getStudyWord(userId, wordId);
    final algorithmType = _algorithmService.defaultAlgorithm;
    final output = _algorithmService.calculate(
      algorithmType: algorithmType,
      input: SRSInput.initial(ReviewRating.good),
    );
    final now = DateTime.now();
    final context = _LearningEntryContext(
      now: now,
      algorithmType: algorithmType,
      output: output,
    );

    // ========= 情况 1：不存在记录，尝试 auto-create learning =========
    if (existing == null) {
      final state = StudyWord(
        id: 0,
        userId: userId,
        wordId: wordId,
        userState: LearningStatus.learning,
        nextReviewAt: output.nextReviewAt,
        lastReviewedAt: null,
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

      // ---- 本线程成功创建：进入 learning ----
      if (insertedRowId > 0) {
        logger.info(
          '[WordState] wordId=$wordId userId=$userId null -> learning',
        );
        return context;
      }

      // ---- 并发被抢先创建：seen -> learning ----
      final after = await _repo.getStudyWord(userId, wordId);
      if (after == null) return context;

      if (after.userState != LearningStatus.learning) {
        await _repo.updateStudyWord(
          after.copyWith(
            userState: LearningStatus.learning,
            nextReviewAt: output.nextReviewAt,
            interval: output.interval.round(),
            easeFactor: output.easeFactor,
            stability: output.stability,
            difficulty: output.difficulty,
            updatedAt: now,
          ),
        );

        final fromState = after.userState == LearningStatus.mastered
            ? 'mastered'
            : after.userState == LearningStatus.ignored
            ? 'ignored'
            : 'seen';
        logger.info(
          '[WordState] wordId=$wordId userId=$userId $fromState -> learning',
        );
      }
      return context;
    }

    // ========= 情况 2：已有记录 =========
    if (existing.userState != LearningStatus.learning) {
      await _repo.updateStudyWord(
        existing.copyWith(
          userState: LearningStatus.learning,
          nextReviewAt: output.nextReviewAt,
          interval: output.interval.round(),
          easeFactor: output.easeFactor,
          stability: output.stability,
          difficulty: output.difficulty,
          updatedAt: now,
        ),
      );

      final fromState = existing.userState == LearningStatus.mastered
          ? 'mastered'
          : existing.userState == LearningStatus.ignored
          ? 'ignored'
          : 'seen';
      logger.info(
        '[WordState] wordId=$wordId userId=$userId $fromState -> learning',
      );
    }
    return context;
  }

  /// 标记单词为已掌握（learning -> mastered）。
  ///
  /// 伪代码：
  /// markWordAsMastered(userId, wordId):
  ///   s = repo.get(userId, wordId)
  ///   if s == null: return (warn)
  ///   now = now()
  ///   s2 = s.copy(status=mastered, nextReviewAt=null, updatedAt=now)
  ///   repo.update(s2)
  ///   log mastered (optional)
  Future<void> markWordAsMastered(int userId, int wordId) async {
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
      logger.info(
        '[WordState] wordId=$wordId userId=$userId learning -> mastered via mark_mastered',
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

    try {
      await _studyLogCommand.logMarkMastered(userId: userId, wordId: wordId);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// 恢复学习（mastered / ignored -> seen）
  Future<void> restoreToSeen({required int userId, required int wordId}) async {
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

      logger.info('[WordState] wordId=$wordId userId=$userId restore -> seen');
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

  /// 切换忽略状态（忽略按钮）。
  ///
  /// 伪代码：
  /// toggleWordIgnored(userId, wordId):
  ///   s = repo.get(userId, wordId)
  ///   now = now()
  ///   if s == null:
  ///      insert status=ignored (nextReviewAt=null)
  ///      log ignored (optional)
  ///      return
  ///   if s.status == ignored:
  ///      s2 = s.copy(status=seen, nextReviewAt=null, updatedAt=now)
  ///   else:
  ///      s2 = s.copy(status=ignored, nextReviewAt=null, updatedAt=now)
  ///   repo.update(s2)
  ///   log ignored (optional)
  Future<void> toggleWordIgnored(int userId, int wordId) async {
    bool shouldLogIgnored = false;

    try {
      final existing = await _repo.getStudyWord(userId, wordId);
      final now = DateTime.now();

      if (existing == null) {
        logger.warning('单词学习状态不存在: userId=$userId, wordId=$wordId');
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
        logger.info(
          '[WordState] wordId=$wordId userId=$userId seen -> ignored via toggle_ignored',
        );
        shouldLogIgnored = true;
      } else if (existing.userState == LearningStatus.ignored) {
        final updated = existing.copyWith(
          userState: LearningStatus.seen,
          nextReviewAt: null,
          updatedAt: now,
        );
        await _repo.updateStudyWord(updated);
        logger.info(
          '[WordState] wordId=$wordId userId=$userId ignored -> seen via restore_seen',
        );
        return;
      } else {
        final updated = existing.copyWith(
          userState: LearningStatus.ignored,
          nextReviewAt: null,
          updatedAt: now,
        );
        await _repo.updateStudyWord(updated);
        final fromState = existing.userState == LearningStatus.learning
            ? 'learning'
            : existing.userState == LearningStatus.mastered
            ? 'mastered'
            : 'seen';
        logger.info(
          '[WordState] wordId=$wordId userId=$userId $fromState -> ignored via toggle_ignored',
        );
        shouldLogIgnored = true;
      }
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPDATE',
        table: 'study_words',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    if (!shouldLogIgnored) return;

    try {
      await _studyLogCommand.logMarkIgnored(userId: userId, wordId: wordId);
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'INSERT',
        table: 'study_logs',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
