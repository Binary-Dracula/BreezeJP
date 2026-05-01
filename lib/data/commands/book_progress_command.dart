import 'sync_remote_command.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/learning_status.dart';
import '../../core/utils/app_logger.dart';
import '../models/book_progress.dart';
import '../queries/study_word_query.dart';
import '../repositories/book_progress_repository.dart';
import '../repositories/book_progress_repository_provider.dart';
import '../repositories/learning_session_repository.dart';
import '../repositories/learning_session_repository_provider.dart';
import '../repositories/study_word_repository.dart';
import '../repositories/study_word_repository_provider.dart';

final bookProgressCommandProvider = Provider<BookProgressCommand>((ref) {
  return BookProgressCommand(ref);
});

/// 辞书进度命令层：刷新聚合数据 / 重置
class BookProgressCommand {
  BookProgressCommand(this.ref);

  final Ref ref;

  BookProgressRepository get _progressRepo =>
      ref.read(bookProgressRepositoryProvider);
  StudyWordRepository get _studyWordRepo =>
      ref.read(studyWordRepositoryProvider);
  LearningSessionRepository get _sessionRepo =>
      ref.read(learningSessionRepositoryProvider);
  StudyWordQuery get _studyWordQuery => ref.read(studyWordQueryProvider);
  SyncRemoteCommand get _syncRemote => ref.read(syncRemoteCommandProvider);

  /// 重新聚合书籍进度计数（批次结束后调用）
  Future<void> refreshProgress({
    required int userId,
    required String bookId,
    required int newCursor,
    required int totalWordsInBook,
  }) async {
    try {
      final stats = await _studyWordQuery.getBookStudyStats(userId, bookId);
      final learnedCount = stats[LearningStatus.learning] ?? 0;
      final masteredCount = stats[LearningStatus.mastered] ?? 0;
      final ignoredCount = stats[LearningStatus.ignored] ?? 0;
      final touchedCount = learnedCount + masteredCount + ignoredCount;
      final isCompleted = touchedCount >= totalWordsInBook;

      final existing = await _progressRepo.getProgress(userId, bookId);
      final now = DateTime.now();

      final updated = BookProgress(
        id: existing?.id ?? 0,
        userId: userId,
        bookId: bookId,
        totalWords: totalWordsInBook,
        learnedCount: learnedCount,
        masteredCount: masteredCount,
        ignoredCount: ignoredCount,
        isCompleted: isCompleted,
        currentSortCursor: newCursor,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await _progressRepo.upsertProgress(updated);
      await _pushBookProgress(updated);

      logger.info(
        '[BookProgressCmd] refreshed: bookId=$bookId cursor=$newCursor '
        'learned=$learnedCount mastered=$masteredCount ignored=$ignoredCount',
      );
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'UPSERT',
        table: 'book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _pushBookProgress(BookProgress progress) async {
    try {
      await _syncRemote.pushBookProgress(
        progress: progress,
        operation: 'upsert',
      );
    } catch (e, stackTrace) {
      logger.warning('书籍进度已写本地，云端同步稍后重试: ${progress.bookId}');
      logger.error('书籍进度同步失败', e, stackTrace);
    }
  }

  /// 完全重置某本书的学习数据（删除 study_words + learning_sessions + book_progress）
  Future<void> resetBook({required int userId, required String bookId}) async {
    try {
      await _studyWordRepo.deleteAllByBook(userId, bookId);
      await _sessionRepo.deleteAllByBook(userId, bookId);
      await _progressRepo.deleteProgress(userId, bookId);

      logger.info('[BookProgressCmd] reset: userId=$userId bookId=$bookId');
    } catch (e, stackTrace) {
      logger.dbError(
        operation: 'DELETE',
        table: 'study_words + learning_sessions + book_progress',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
