import 'package:breeze_jp/data/queries/vocab_remote_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteWordLearnSession.fromJson', () {
    const word = {
      'id': 'word-1',
      'word': '言葉',
      'reading': 'ことば',
      'part_of_speech': 'noun',
      'primary_meaning': '词语',
      'book_sort_order': 1,
      'rich_content': {'meanings': []},
      'examples': <Map<String, dynamic>>[],
    };

    test('parses wrapped API payload', () {
      final session = RemoteWordLearnSession.fromJson({
        'data': {
          'session_id': 'remote-session-1',
          'book_id': 'book-1',
          'batch_start_sort': 0,
          'batch_end_sort': 10,
          'words': [word],
        },
        'meta': {'total_words': 120, 'resumed': false},
      });

      expect(session.sessionId, 'remote-session-1');
      expect(session.bookId, 'book-1');
      expect(session.batchStartSort, 0);
      expect(session.batchEndSort, 10);
      expect(session.totalWords, 120);
      expect(session.resumed, isFalse);
      expect(session.words, hasLength(1));
      expect(session.rawWordsJson, hasLength(1));
    });

    test('allows empty wrapped payload without session id', () {
      final session = RemoteWordLearnSession.fromJson({
        'data': {
          'book_id': 'book-1',
          'batch_start_sort': 0,
          'batch_end_sort': 0,
          'session_id': null,
          'words': const [],
        },
        'meta': {'total_words': 50, 'resumed': false},
      });

      expect(session.sessionId, isNull);
      expect(session.totalWords, 50);
      expect(session.resumed, isFalse);
      expect(session.words, isEmpty);
    });

    test('rejects legacy unwrapped payload', () {
      expect(
        () => RemoteWordLearnSession.fromJson({
          'session_id': 'remote-session-3',
          'book_id': 'book-1',
          'batch_start_sort': 10,
          'batch_end_sort': 20,
          'words': [word],
          'total_words': 120,
          'resumed': false,
        }),
        throwsFormatException,
      );
    });

    test('rejects wrapped payload without session id for non-empty words', () {
      expect(
        () => RemoteWordLearnSession.fromJson({
          'data': {
            'book_id': 'book-1',
            'batch_start_sort': 0,
            'batch_end_sort': 10,
            'words': [word],
          },
          'meta': {'total_words': 120, 'resumed': false},
        }),
        throwsFormatException,
      );
    });
  });
}
