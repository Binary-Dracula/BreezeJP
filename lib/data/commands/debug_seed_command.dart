import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../commands/active_user_command.dart';
import '../commands/active_user_command_provider.dart';
import '../models/kana_learning_state.dart';
import '../models/study_word.dart';
import '../models/read/word_list_item.dart';
import '../queries/word_read_queries.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kana_repository_provider.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

class DebugSeedResult {
  DebugSeedResult({
    required this.userId,
    required this.requestedCount,
    required this.wordSelected,
    required this.wordInserted,
    required this.wordUpdated,
    required this.wordSkipped,
    required this.kanaSelected,
    required this.kanaInserted,
    required this.kanaUpdated,
    required this.kanaSkipped,
  });

  final int userId;
  final int requestedCount;
  final int wordSelected;
  final int wordInserted;
  final int wordUpdated;
  final int wordSkipped;
  final int kanaSelected;
  final int kanaInserted;
  final int kanaUpdated;
  final int kanaSkipped;

  String summary() {
    return 'Seeded user=$userId, words=$wordSelected (new=$wordInserted, '
        'update=$wordUpdated, skip=$wordSkipped), '
        'kana=$kanaSelected (new=$kanaInserted, update=$kanaUpdated, '
        'skip=$kanaSkipped)';
  }
}

class DebugSeedCommand {
  DebugSeedCommand(this.ref);

  final Ref ref;

  ActiveUserCommand get _activeUserCommand =>
      ref.read(activeUserCommandProvider);
  WordReadQueries get _wordReadQueries => ref.read(wordReadQueriesProvider);
  StudyWordRepository get _studyWordRepository =>
      ref.read(studyWordRepositoryProvider);
  KanaRepository get _kanaRepository => ref.read(kanaRepositoryProvider);

  Future<DebugSeedResult> seedLearningData({int perType = 10}) async {
    final user = await _activeUserCommand.ensureActiveUser();
    final userId = user.id;
    final now = DateTime.now();
    final dueAt = now.subtract(const Duration(minutes: 5));
    final lastReviewedAt = now.subtract(const Duration(days: 1));

    final wordCandidates = await _getWordCandidates(perType);
    final wordSelected = wordCandidates.take(perType).toList();
    var wordInserted = 0;
    var wordUpdated = 0;
    var wordSkipped = 0;

    for (final item in wordSelected) {
      final existing = await _studyWordRepository.getStudyWord(
        userId,
        item.word.id,
      );

      if (existing == null) {
        final state = StudyWord(
          id: 0,
          userId: userId,
          wordId: item.word.id,
          userState: LearningStatus.learning,
          nextReviewAt: dueAt,
          lastReviewedAt: lastReviewedAt,
          interval: 1,
          easeFactor: AppConstants.defaultEaseFactor,
          stability: 0,
          difficulty: 0,
          streak: 0,
          totalReviews: 1,
          failCount: 0,
          createdAt: now,
          updatedAt: now,
        );
        await _studyWordRepository.createStudyWordIgnoreConflict(state);
        wordInserted += 1;
        continue;
      }

      final needsUpdate =
          existing.userState != LearningStatus.learning ||
          existing.nextReviewAt == null ||
          existing.nextReviewAt!.isAfter(now);
      if (!needsUpdate) {
        wordSkipped += 1;
        continue;
      }

      final updated = existing.copyWith(
        userState: LearningStatus.learning,
        nextReviewAt: dueAt,
        lastReviewedAt: existing.lastReviewedAt ?? lastReviewedAt,
        interval: existing.interval ?? 1,
        easeFactor: existing.easeFactor ?? AppConstants.defaultEaseFactor,
        stability: existing.stability ?? 0,
        difficulty: existing.difficulty ?? 0,
        totalReviews: existing.totalReviews == 0 ? 1 : existing.totalReviews,
        updatedAt: now,
      );
      await _studyWordRepository.updateStudyWord(updated);
      wordUpdated += 1;
    }

    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final dueAtSeconds = nowSeconds - 300;
    final lastReviewedAtSeconds = nowSeconds - 86400;

    final kanaLetters = await _kanaRepository.getAllKanaLetters();
    final kanaSelected =
        kanaLetters.take(perType).map((letter) => letter.id).toList();
    var kanaInserted = 0;
    var kanaUpdated = 0;
    var kanaSkipped = 0;

    for (final kanaId in kanaSelected) {
      final existing = await _kanaRepository.getKanaLearningState(
        userId,
        kanaId,
      );

      if (existing == null) {
        final state = KanaLearningState(
          id: 0,
          userId: userId,
          kanaId: kanaId,
          learningStatus: LearningStatus.learning,
          nextReviewAt: dueAtSeconds,
          lastReviewedAt: lastReviewedAtSeconds,
          interval: 1.0,
          easeFactor: AppConstants.defaultEaseFactor,
          stability: 0,
          difficulty: 0,
          streak: 0,
          totalReviews: 1,
          failCount: 0,
          createdAt: nowSeconds,
          updatedAt: nowSeconds,
        );
        await _kanaRepository.insertKanaLearningState(state);
        kanaInserted += 1;
        continue;
      }

      final needsUpdate =
          existing.learningStatus != LearningStatus.learning ||
          existing.nextReviewAt == null ||
          existing.nextReviewAt! > nowSeconds;
      if (!needsUpdate) {
        kanaSkipped += 1;
        continue;
      }

      final updated = existing.copyWith(
        learningStatus: LearningStatus.learning,
        nextReviewAt: dueAtSeconds,
        lastReviewedAt: existing.lastReviewedAt ?? lastReviewedAtSeconds,
        interval: existing.interval == 0 ? 1.0 : existing.interval,
        easeFactor: existing.easeFactor == 0
            ? AppConstants.defaultEaseFactor
            : existing.easeFactor,
        totalReviews: existing.totalReviews == 0 ? 1 : existing.totalReviews,
        updatedAt: nowSeconds,
      );
      await _kanaRepository.updateKanaLearningState(updated);
      kanaUpdated += 1;
    }

    final result = DebugSeedResult(
      userId: userId,
      requestedCount: perType,
      wordSelected: wordSelected.length,
      wordInserted: wordInserted,
      wordUpdated: wordUpdated,
      wordSkipped: wordSkipped,
      kanaSelected: kanaSelected.length,
      kanaInserted: kanaInserted,
      kanaUpdated: kanaUpdated,
      kanaSkipped: kanaSkipped,
    );

    logger.info('[DEBUG] ${result.summary()}');
    return result;
  }

  Future<List<WordListItem>> _getWordCandidates(int perType) async {
    final candidates = await _wordReadQueries.getWordListItems(
      limit: perType * 5,
    );
    return candidates
        .where((item) => (item.primaryMeaning ?? '').trim().isNotEmpty)
        .toList();
  }
}
