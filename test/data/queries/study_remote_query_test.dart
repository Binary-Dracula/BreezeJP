import 'package:breeze_jp/data/queries/study_remote_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('review session decode', () {
    test(
      'restores word review session when stored timestamps are unix seconds',
      () {
        final session = RemoteWordReviewSession.fromJson({
          'session_id': 'word-session-1',
          'current_index': 0,
          'current_phase': 'testing',
          'has_mistake_on_current': false,
          'items': [
            {
              'word_state': {
                'word_id': 'word-1',
                'book_id': 'book-1',
                'user_state': 1,
                'next_review_at': 1713574800,
                'last_reviewed_at': 1713571200,
                'first_learned_at': 1713567600,
                'interval': 1,
                'ease_factor': 2.5,
                'stability': 0.2,
                'difficulty': 0.4,
                'streak': 1,
                'total_reviews': 2,
                'fail_count': 0,
                'created_at': 1713571200,
                'updated_at': 1713571200,
              },
              'word_detail': {
                'id': 'word-1',
                'word': '言葉',
                'reading': 'ことば',
                'part_of_speech': 'noun',
                'primary_meaning': '词语',
                'has_audio': false,
                'rich_content': {'meanings': []},
                'examples': const [],
              },
              'question_type': 'word_to_meaning',
              'audio_source': null,
              'meaning': '词语',
              'reading': 'ことば',
              'options': const ['词语', '句子', '语法', '文章'],
            },
          ],
        }, 1);

        expect(session.sessionId, 'word-session-1');
        expect(session.items, hasLength(1));
        expect(
          session.items.first.studyWord.createdAt.millisecondsSinceEpoch,
          1713571200 * 1000,
        );
        expect(
          session.items.first.studyWord.updatedAt.millisecondsSinceEpoch,
          1713571200 * 1000,
        );
      },
    );

    test('treats legacy empty list payload as empty word review session', () {
      final session = RemoteWordReviewSession.fromApiData(const [], 1);

      expect(session.sessionId, isNull);
      expect(session.currentIndex, 0);
      expect(session.currentPhase, 'testing');
      expect(session.hasMistakeOnCurrent, isFalse);
      expect(session.items, isEmpty);
    });
  });
}
