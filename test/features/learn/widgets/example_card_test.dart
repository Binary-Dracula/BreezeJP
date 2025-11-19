import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruby_text/ruby_text.dart';

/// 测试例句解析逻辑
void main() {
  group('ExampleCard 解析测试', () {
    test('解析带假名和加粗的例句', () {
      // 测试用例: 友達[ともだち]が 誕生[たんじょう] 日[び]プレゼントを<b>くれた</b>
      final input = '友達[ともだち]が 誕生[たんじょう] 日[び]プレゼントを<b>くれた</b>';

      final result = _parseSegmentToRubyTextData(
        input,
        isBoldContext: false,
        theme: ThemeData.light(),
      );

      // 期望结果
      // 1. RubyTextData("友達", ruby: "ともだち")
      // 2. RubyTextData("が ")
      // 3. RubyTextData("誕生", ruby: "たんじょう")
      // 4. RubyTextData(" ")
      // 5. RubyTextData("日", ruby: "び")
      // 6. RubyTextData("プレゼントを")
      // 7. RubyTextData("くれた", style: bold)

      expect(result.length, 7);

      // 验证每个部分
      expect(result[0].text, '友達');
      expect(result[0].ruby, 'ともだち');

      expect(result[1].text, 'が ');
      expect(result[1].ruby, null);

      expect(result[2].text, '誕生');
      expect(result[2].ruby, 'たんじょう');

      expect(result[3].text, ' ');
      expect(result[3].ruby, null);

      expect(result[4].text, '日');
      expect(result[4].ruby, 'び');

      expect(result[5].text, 'プレゼントを');
      expect(result[5].ruby, null);

      expect(result[6].text, 'くれた');
      expect(result[6].ruby, null);
      expect(result[6].style?.fontWeight, FontWeight.bold);
    });

    test('解析纯文本', () {
      final input = 'これは普通の文です';
      final result = _parseSegmentToRubyTextData(
        input,
        isBoldContext: false,
        theme: ThemeData.light(),
      );

      expect(result.length, 1);
      expect(result[0].text, 'これは普通の文です');
      expect(result[0].ruby, null);
    });

    test('解析只有假名的文本', () {
      final input = '学校[がっこう]に行[い]く';
      final result = _parseSegmentToRubyTextData(
        input,
        isBoldContext: false,
        theme: ThemeData.light(),
      );

      expect(result.length, 3);
      expect(result[0].text, '学校');
      expect(result[0].ruby, 'がっこう');
      expect(result[1].text, 'に');
      expect(result[2].text, '行');
      expect(result[2].ruby, 'い');
    });

    test('解析只有加粗的文本', () {
      final input = 'これは<b>重要</b>です';
      final result = _parseSegmentToRubyTextData(
        input,
        isBoldContext: false,
        theme: ThemeData.light(),
      );

      expect(result.length, 3);
      expect(result[0].text, 'これは');
      expect(result[1].text, '重要');
      expect(result[1].style?.fontWeight, FontWeight.bold);
      expect(result[2].text, 'です');
    });

    test('解析加粗内带假名', () {
      final input = '<b>学校[がっこう]</b>に行く';
      final result = _parseSegmentToRubyTextData(
        input,
        isBoldContext: false,
        theme: ThemeData.light(),
      );

      expect(result.length, 2);
      expect(result[0].text, '学校');
      expect(result[0].ruby, 'がっこう');
      expect(result[0].style?.fontWeight, FontWeight.bold);
      expect(result[1].text, 'に行く');
    });
  });
}

/// 复制自 ExampleCard 的解析方法（用于测试）
List<RubyTextData> _parseSegmentToRubyTextData(
  String segment, {
  required bool isBoldContext,
  required ThemeData theme,
}) {
  final List<RubyTextData> result = [];

  final pattern = RegExp(
    r'<b>(.*?)<\/b>' // group1: bold text
    r'|(\S)\[([^\]]+)\]' // group2: 单个非空白字符, group3: ruby
    r'|(.)', // group4: 任意单个字符
    dotAll: true,
  );

  final matches = pattern.allMatches(segment);

  for (final match in matches) {
    // Case 1: <b>...</b>
    final boldText = match.group(1);
    if (boldText != null) {
      final innerTokens = _parseSegmentToRubyTextData(
        boldText,
        isBoldContext: true,
        theme: theme,
      );
      result.addAll(innerTokens);
      continue;
    }

    // Case 2: 单个字符[ruby]
    final base = match.group(2);
    final ruby = match.group(3);
    if (base != null && ruby != null) {
      result.add(
        RubyTextData(
          base,
          ruby: ruby,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
            color: isBoldContext
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          rubyStyle: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
      continue;
    }

    // Case 3: 单个字符
    final singleChar = match.group(4);
    if (singleChar != null) {
      // 合并连续的普通字符
      if (result.isNotEmpty &&
          result.last.ruby == null &&
          result.last.style?.fontWeight ==
              (isBoldContext ? FontWeight.bold : FontWeight.normal)) {
        final lastText = result.last.text;
        result.removeLast();
        result.add(
          RubyTextData(
            lastText + singleChar,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
              color: isBoldContext
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        );
      } else {
        result.add(
          RubyTextData(
            singleChar,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
              color: isBoldContext
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        );
      }
    }
  }

  return result;
}
