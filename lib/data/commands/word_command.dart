import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/algorithm/algorithm_service.dart';
import '../../core/algorithm/algorithm_service_provider.dart';
import '../../core/algorithm/srs_types.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/study_log.dart';
import '../models/study_word.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';
import '../repositories/word_repository.dart';
import '../repositories/word_repository_provider.dart';
import 'study_log_command.dart';

/// WordLearningState 与 StudyWord 使用同一数据结构，避免重复模型。
typedef WordLearningState = StudyWord;

final wordCommandProvider = Provider<WordCommand>((ref) {
  return WordCommand(ref);
});

/// Word 行为命令层（学习状态写入 / 生命周期控制）
class WordCommand {
  WordCommand(this.ref);

  final Ref ref;

  StudyWordRepository get _repo => ref.read(studyWordRepositoryProvider);
  WordRepository get _wordRepo => ref.read(wordRepositoryProvider);
  AlgorithmService get _algorithmService =>
      ref.read(algorithmServiceProvider);
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

  /// 进入学习阶段（仅允许 seen -> learning）。
  ///
  /// 伪代码：
  /// enterWordLearningIfNeeded(userId, wordId):
  ///   s = repo.get(userId, wordId)
  ///   if s == null: return (warn)
  ///   if s.status != seen: return
  ///   out = algorithm.calculate(initial GOOD)
  ///   now = now()
  ///   s2 = s.copy(status=learning, nextReviewAt=out.nextReviewAt,
  ///             interval=out.interval, easeFactor=out.easeFactor,
  ///             stability=out.stability, difficulty=out.difficulty,
  ///             updatedAt=now)
  ///   repo.update(s2)
  ///   log firstLearn (optional)
  Future<void> enterWordLearningIfNeeded(int userId, int wordId) async {
    AlgorithmType? firstLearnAlgorithm;
    SRSOutput? firstLearnOutput;

    final existing = await _repo.getStudyWord(userId, wordId);

    // -------- 情况 1：不存在记录，尝试 auto-create learning --------
    if (existing == null) {
      final algorithmType = _algorithmService.defaultAlgorithm;
      final output = _algorithmService.calculate(
        algorithmType: algorithmType,
        input: SRSInput.initial(ReviewRating.good),
      );
      final now = DateTime.now();

      final state = StudyWord(
        id: 0,
        userId: userId,
        wordId: wordId,
        userState: LearningStatus.learning,
        nextReviewAt: output.nextReviewAt,
        lastReviewedAt: null,
        interval: output.interval,
        easeFactor: output.easeFactor,
        stability: output.stability,
        difficulty: output.difficulty,
        streak: 0,
        totalReviews: 0,
        failCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final insertedRowId =
          await _repo.createStudyWordIgnoreConflict(state);

      if (insertedRowId > 0) {
        // 本线程成功创建
        logger.info(
          '[WordState] wordId=$wordId userId=$userId null -> learning via enter_learning(auto_create)',
        );
        firstLearnAlgorithm = algorithmType;
        firstLearnOutput = output;
      } else {
        // 被并发插入抢先，回读后判断是否需要 seen -> learning
        final after = await _repo.getStudyWord(userId, wordId);
        if (after == null || after.userState != LearningStatus.seen) {
          return;
        }

        await _repo.updateStudyWord(after.copyWith(
          userState: LearningStatus.learning,
          nextReviewAt: output.nextReviewAt,
          interval: output.interval,
          easeFactor: output.easeFactor,
          stability: output.stability,
          difficulty: output.difficulty,
          updatedAt: now,
        ));

        logger.info(
          '[WordState] wordId=$wordId userId=$userId seen -> learning via enter_learning',
        );
        firstLearnAlgorithm = algorithmType;
        firstLearnOutput = output;
      }
    }

    // -------- 情况 2：已有记录且为 seen --------
    else if (existing.userState == LearningStatus.seen) {
      final algorithmType = _algorithmService.defaultAlgorithm;
      final output = _algorithmService.calculate(
        algorithmType: algorithmType,
        input: SRSInput.initial(ReviewRating.good),
      );
      final now = DateTime.now();

      await _repo.updateStudyWord(existing.copyWith(
        userState: LearningStatus.learning,
        nextReviewAt: output.nextReviewAt,
        interval: output.interval,
        easeFactor: output.easeFactor,
        stability: output.stability,
        difficulty: output.difficulty,
        updatedAt: now,
      ));

      logger.info(
        '[WordState] wordId=$wordId userId=$userId seen -> learning via enter_learning',
      );
      firstLearnAlgorithm = algorithmType;
      firstLearnOutput = output;
    }

    // -------- 其他状态：no-op --------
    else {
      return;
    }

    // -------- 写 firstLearn 日志（仅一次） --------
    if (firstLearnAlgorithm == null || firstLearnOutput == null) return;

    await _studyLogCommand.logFirstLearn(
      userId: userId,
      wordId: wordId,
      durationMs: 0,
      intervalAfter: firstLearnOutput.interval,
      easeFactorAfter: firstLearnOutput.easeFactor,
      nextReviewAtAfter: firstLearnOutput.nextReviewAt,
      algorithm:
          AlgorithmService.getAlgorithmValue(firstLearnAlgorithm),
      fsrsStabilityAfter: firstLearnOutput.stability,
      fsrsDifficultyAfter: firstLearnOutput.difficulty,
    );
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
      await _studyLogCommand.logMarkMastered(
        userId: userId,
        wordId: wordId,
      );
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
