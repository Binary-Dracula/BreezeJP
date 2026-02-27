import 'package:flutter_test/flutter_test.dart';
import 'package:breeze_jp/core/utils/furigana_parser.dart';

void main() {
  group('FuriganaParser', () {
    test('parses plain text correctly', () {
      final result = FuriganaParser.parse('こんにちは');
      expect(result.length, 1);
      expect(result.first.text, 'こんにちは');
      expect(result.first.ruby, isNull);
    });

    test('parses kanji with furigana', () {
      final result = FuriganaParser.parse('高市[たかいち]総理大臣[そうりだいじん]が');
      expect(result.length, 3);
      expect(result[0].text, '高市');
      expect(result[0].ruby, 'たかいち');
      expect(result[1].text, '総理大臣');
      expect(result[1].ruby, 'そうりだいじん');
      expect(result[2].text, 'が');
      expect(result[2].ruby, isNull);
    });

    test('ignores katakana when attached to kanji with furigana', () {
      final result = FuriganaParser.parse('トランプ大統領[だいとうりょう]と会[あ]って');
      expect(result.length, 5);
      expect(result[0].text, 'トランプ');
      expect(result[0].ruby, isNull);
      expect(result[1].text, '大統領');
      expect(result[1].ruby, 'だいとうりょう');
      expect(result[2].text, 'と');
      expect(result[2].ruby, isNull);
      expect(result[3].text, '会');
      expect(result[3].ruby, 'あ');
      expect(result[4].text, 'って');
      expect(result[4].ruby, isNull);
    });

    test('handles English acronyms mixed with kanji', () {
      final result = FuriganaParser.parse('iPS細胞[さいぼう]');
      expect(result.length, 2);
      expect(result[0].text, 'iPS');
      expect(result[0].ruby, isNull);
      expect(result[1].text, '細胞');
      expect(result[1].ruby, 'さいぼう');
    });

    test('handles numbers and kanji grouped together', () {
      final result = FuriganaParser.parse('10日[とおか]までに');
      expect(result.length, 2);
      expect(result[0].text, '10日');
      expect(result[0].ruby, 'とおか');
      expect(result[1].text, 'までに');
      expect(result[1].ruby, isNull);
    });

    test('handles separated numbers and kanji', () {
      final result = FuriganaParser.parse('24[にじゅうよっ]日[か]から');
      expect(result.length, 3);
      expect(result[0].text, '24');
      expect(result[0].ruby, 'にじゅうよっ');
      expect(result[1].text, '日');
      expect(result[1].ruby, 'か');
      expect(result[2].text, 'から');
      expect(result[2].ruby, isNull);
    });

    test('handles English acronyms with furigana', () {
      final result = FuriganaParser.parse('ＩＴ[アイティー]企業[きぎょう]');
      expect(result.length, 2);
      expect(result[0].text, 'ＩＴ');
      expect(result[0].ruby, 'アイティー');
      expect(result[1].text, '企業');
      expect(result[1].ruby, 'きぎょう');
    });
  });
}
