import 'package:breeze_jp/core/constants/learning_status.dart';
import 'package:breeze_jp/data/commands/book_progress_command.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/models/book_progress.dart';
import 'package:breeze_jp/data/queries/study_word_query.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository.dart';
import 'package:breeze_jp/data/repositories/book_progress_repository_provider.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository_provider.dart';
import 'package:breeze_jp/data/repositories/study_word_repository.dart';
import 'package:breeze_jp/data/repositories/study_word_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBookProgressRepository extends Mock
    implements BookProgressRepository {}

class _MockStudyWordRepository extends Mock implements StudyWordRepository {}

class _MockLearningSessionRepository extends Mock
    implements LearningSessionRepository {}

class _MockStudyWordQuery extends Mock implements StudyWordQuery {}

class _MockSyncRemoteCommand extends Mock implements SyncRemoteCommand {}

void main() {
  late _MockBookProgressRepository progressRepository;
  late _MockStudyWordRepository studyWordRepository;
  late _MockLearningSessionRepository sessionRepository;
  late _MockStudyWordQuery studyWordQuery;
  late _MockSyncRemoteCommand syncRemoteCommand;

  final existingProgress = BookProgress(
    id: 1,
    userId: 1,
    bookId: 'book-1',
    totalWords: 100,
    learnedCount: 9,
    masteredCount: 0,
    ignoredCount: 0,
    isCompleted: false,
    currentSortCursor: 9,
    createdAt: DateTime.utc(2026, 4, 26),
    updatedAt: DateTime.utc(2026, 4, 26),
  );

  setUpAll(() {
    registerFallbackValue(existingProgress);
  });

  setUp(() {
    progressRepository = _MockBookProgressRepository();
    studyWordRepository = _MockStudyWordRepository();
    sessionRepository = _MockLearningSessionRepository();
    studyWordQuery = _MockStudyWordQuery();
    syncRemoteCommand = _MockSyncRemoteCommand();
  });

  test('refreshProgress pushes latest cursor to remote sync', () async {
    when(() => studyWordQuery.getBookStudyStats(1, 'book-1')).thenAnswer(
      (_) async => {
        LearningStatus.learning: 10,
        LearningStatus.mastered: 0,
        LearningStatus.ignored: 0,
      },
    );
    when(
      () => progressRepository.getProgress(1, 'book-1'),
    ).thenAnswer((_) async => existingProgress);
    when(
      () => progressRepository.upsertProgress(any()),
    ).thenAnswer((_) async {});
    when(
      () => syncRemoteCommand.pushBookProgress(
        progress: any(named: 'progress'),
        operation: 'upsert',
      ),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        bookProgressRepositoryProvider.overrideWith(
          (ref) => progressRepository,
        ),
        studyWordRepositoryProvider.overrideWith((ref) => studyWordRepository),
        learningSessionRepositoryProvider.overrideWith(
          (ref) => sessionRepository,
        ),
        studyWordQueryProvider.overrideWith((ref) => studyWordQuery),
        syncRemoteCommandProvider.overrideWith((ref) => syncRemoteCommand),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(bookProgressCommandProvider)
        .refreshProgress(
          userId: 1,
          bookId: 'book-1',
          newCursor: 10,
          totalWordsInBook: 100,
        );

    final updatedProgress =
        verify(
              () => progressRepository.upsertProgress(captureAny()),
            ).captured.single
            as BookProgress;
    expect(updatedProgress.currentSortCursor, 10);
    expect(updatedProgress.totalWords, 100);

    final pushedProgress =
        verify(
              () => syncRemoteCommand.pushBookProgress(
                progress: captureAny(named: 'progress'),
                operation: 'upsert',
              ),
            ).captured.single
            as BookProgress;
    expect(pushedProgress.currentSortCursor, 10);
    expect(pushedProgress.bookId, 'book-1');
  });
}
