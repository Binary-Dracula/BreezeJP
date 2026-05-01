import 'package:breeze_jp/data/models/learning_session.dart';
import 'package:breeze_jp/data/repositories/learning_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockDatabase extends Mock implements Database {}

class _MockTransaction extends Mock implements Transaction {}

typedef _TxnAction = Future<int> Function(Transaction txn);

Future<int> _fakeTxnAction(Transaction txn) async => 0;

void main() {
  late _MockDatabase database;
  late _MockTransaction transaction;
  late LearningSessionRepository repository;

  setUpAll(() {
    registerFallbackValue(_fakeTxnAction);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    database = _MockDatabase();
    transaction = _MockTransaction();
    repository = LearningSessionRepository(() async => database);

    when(() => database.transaction<int>(any())).thenAnswer((invocation) async {
      final action = invocation.positionalArguments.first as _TxnAction;
      return action(transaction);
    });
    when(
      () => transaction.update(
        'learning_sessions',
        any(),
        where: any(named: 'where'),
        whereArgs: any(named: 'whereArgs'),
      ),
    ).thenAnswer((_) async => 1);
  });

  test(
    'replaces stale completed session before marking current session completed',
    () async {
      final session = LearningSession(
        id: 2,
        userId: 1,
        bookId: 'book-1',
        wordIds: const ['word-11'],
        wordsPayload: '[]',
        currentIndex: 9,
        batchStartSort: 10,
        batchEndSort: 20,
        startedAt: DateTime.utc(2026, 4, 26),
        status: 'completed',
        createdAt: DateTime.utc(2026, 4, 26),
        updatedAt: DateTime.utc(2026, 4, 26),
      );

      when(
        () => transaction.delete(
          'learning_sessions',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await repository.updateSession(session);

      verifyInOrder([
        () => transaction.delete(
          'learning_sessions',
          where: 'user_id = ? AND book_id = ? AND status = ? AND id != ?',
          whereArgs: [1, 'book-1', 'completed', 2],
        ),
        () => transaction.update(
          'learning_sessions',
          any(),
          where: 'id = ?',
          whereArgs: [2],
        ),
      ]);
    },
  );

  test(
    'does not touch completed rows when updating an active session',
    () async {
      final session = LearningSession(
        id: 2,
        userId: 1,
        bookId: 'book-1',
        wordIds: const ['word-11'],
        wordsPayload: '[]',
        currentIndex: 5,
        batchStartSort: 10,
        batchEndSort: 20,
        startedAt: DateTime.utc(2026, 4, 26),
        status: 'active',
        createdAt: DateTime.utc(2026, 4, 26),
        updatedAt: DateTime.utc(2026, 4, 26),
      );

      await repository.updateSession(session);

      verifyNever(
        () => transaction.delete(
          'learning_sessions',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      );
      verify(
        () => transaction.update(
          'learning_sessions',
          any(),
          where: 'id = ?',
          whereArgs: [2],
        ),
      ).called(1);
    },
  );
}
