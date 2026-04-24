import 'package:breeze_jp/data/commands/book_sync_command.dart';
import 'package:breeze_jp/data/models/vocab_book.dart';
import 'package:breeze_jp/data/queries/vocab_remote_query.dart';
import 'package:breeze_jp/data/repositories/book_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVocabRemoteQuery extends Mock implements VocabRemoteQuery {}

class _MockBookRepository extends Mock implements BookRepository {}

void main() {
  late SharedPreferences prefs;
  late _MockVocabRemoteQuery remoteQuery;
  late _MockBookRepository repository;
  late BookSyncCommand command;

  final availableBook = VocabBook(
    id: 'book-1',
    title: 'Available',
    isAvailable: true,
    updatedAt: DateTime.utc(2026, 4, 22, 10),
  );
  final unavailableBook = VocabBook(
    id: 'book-1',
    title: 'Unavailable',
    isAvailable: false,
    updatedAt: DateTime.utc(2026, 4, 22, 11),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remoteQuery = _MockVocabRemoteQuery();
    repository = _MockBookRepository();
    command = BookSyncCommand(
      prefs: prefs,
      remoteQuery: remoteQuery,
      bookRepository: repository,
    );
  });

  test('first sync loads available books and stores timestamp', () async {
    when(() => remoteQuery.fetchBooks()).thenAnswer(
      (_) async => BookListResponse(
        books: [availableBook],
        serverTime: '2026-04-22T12:00:00Z',
      ),
    );
    when(() => repository.upsertBooks(any())).thenAnswer((_) async {});
    when(
      () => repository.getBookById(any()),
    ).thenAnswer((_) async => availableBook);

    final count = await command.syncBooks();

    expect(count, 1);
    expect(prefs.getString('books_last_sync_time'), '2026-04-22T12:00:00Z');
    verify(() => repository.upsertBooks([availableBook])).called(1);
  });

  test(
    'incremental sync clears selected book when it becomes unavailable',
    () async {
      await prefs.setString('books_last_sync_time', '2026-04-22T10:00:00Z');
      await prefs.setString('selected_book_id', 'book-1');
      when(
        () => remoteQuery.fetchBookSync(since: '2026-04-22T10:00:00Z'),
      ).thenAnswer(
        (_) async => BookSyncResponse(
          books: [unavailableBook],
          serverTime: '2026-04-22T12:00:00Z',
        ),
      );
      when(() => repository.upsertBooks(any())).thenAnswer((_) async {});
      when(
        () => repository.getBookById('book-1'),
      ).thenAnswer((_) async => unavailableBook);

      final count = await command.syncBooks();

      expect(count, 1);
      expect(prefs.getString('selected_book_id'), isNull);
      expect(prefs.getString('books_last_sync_time'), '2026-04-22T12:00:00Z');
    },
  );
}
