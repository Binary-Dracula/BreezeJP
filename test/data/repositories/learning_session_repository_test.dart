import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabase extends Mock implements Database {}

void main() {
  late _MockDatabase database;
  late LearningSessionRepository repository;

  setUpAll(() => registerFallbackValue(<String, Object?>{}));

  setUp(() {
    database = _MockDatabase();
    repository = LearningSessionRepository(() async => database);

    when(
      () => database.update(
        'learning_sessions',
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);
  });

  test('updates session payload and completed status in place', () async {
    final session = LearningSession.wordLearn(
      id: 'session-2',
      userId: 1,
      bookId: 'book-1',
      wordsPayload: '[]',
      currentIndex: 9,
      batchStartSort: 10,
      batchEndSort: 20,
      status: 'completed',
      createdAt: DateTime.utc(2026, 4, 26),
    );

    await repository.updateSession(session);

    verifyNever(
      () => database.delete(
        'learning_sessions',
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    );
    verify(
      () => database.update(
        'learning_sessions',
        any(),
        where: 'id = ?',
        whereArgs: ['session-2'],
      ),
    ).called(1);
  });

  test('queries active review session by session type', () async {
    when(
      () => database.query(
        'learning_sessions',
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        LearningSession(
          id: 'review-1',
          userId: '1',
          sessionType: LearningSessionType.wordReview,
          serverSessionId: 'remote-1',
          bookId: null,
          status: 'active',
          dataPayload:
              '{"initial_items":[],"dynamic_queue":[],"answered_results":[],"current_index":0}',
          createdAt: DateTime.utc(2026, 4, 26),
        ).toMapForInsert(),
      ],
    );

    final session = await repository.getActiveSessionByType(
      1,
      LearningSessionType.wordReview,
    );

    expect(session, isNotNull);
    expect(session!.sessionType, LearningSessionType.wordReview);
    verify(
      () => database.query(
        'learning_sessions',
        where: 'user_id = ? AND session_type = ? AND status = ?',
        whereArgs: ['1', 'word_review', 'active'],
        limit: 1,
      ),
    ).called(1);
  });

  test('filters active word learn session by book id', () async {
    when(
      () => database.query(
        'learning_sessions',
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const <Map<String, Object?>>[]);

    await repository.getActiveSession(1, 'book-1');

    verify(
      () => database.query(
        'learning_sessions',
        where:
            'user_id = ? AND session_type = ? AND book_id = ? AND status = ?',
        whereArgs: ['1', 'word_learn', 'book-1', 'active'],
        limit: 1,
      ),
    ).called(1);
  });
}
