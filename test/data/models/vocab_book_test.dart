import 'package:breeze_jp/data/models/vocab_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VocabBook', () {
    test('fromJson reads availability and updatedAt', () {
      final book = VocabBook.fromJson({
        'id': 'book-1',
        'title': 'N1 Core',
        'subtitle': 'Advanced',
        'description': 'desc',
        'cover_image_key': 'cover.png',
        'is_available': false,
        'has_lessons': true,
        'word_count': 42,
        'sort_order': 3,
        'updated_at': '2026-04-22T10:00:00Z',
      });

      expect(book.id, 'book-1');
      expect(book.isAvailable, isFalse);
      expect(book.wordCount, 42);
      expect(book.sortOrder, 3);
      expect(book.updatedAt, DateTime.parse('2026-04-22T10:00:00Z'));
    });

    test('toMap/fromMap round trips sqlite fields', () {
      final original = VocabBook(
        id: 'book-2',
        title: 'N2',
        isAvailable: true,
        hasLessons: false,
        wordCount: 18,
        sortOrder: 4,
        updatedAt: DateTime.utc(2026, 4, 22, 11),
      );

      final restored = VocabBook.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.isAvailable, isTrue);
      expect(restored.hasLessons, isFalse);
      expect(restored.wordCount, 18);
      expect(restored.sortOrder, 4);
      expect(
        restored.updatedAt?.millisecondsSinceEpoch,
        original.updatedAt?.millisecondsSinceEpoch,
      );
    });
  });
}
