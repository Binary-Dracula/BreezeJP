import 'package:ruby_text/ruby_text.dart';

class FuriganaParser {
  /// Parses text formatted like "高市[たかいち]総理大臣[そうりだいじん]が"
  /// into a list of RubyTextData suitable for the RubyText widget.
  static List<RubyTextData> parse(String text) {
    if (text.isEmpty) return [];

    final List<RubyTextData> result = [];
    int index = 0;

    // 此正则寻找 汉字+数字、字母、或片假名组合，后跟 [假名]。分成不同的组以避免跨类型贪婪匹配。
    final pattern = RegExp(
      r'([\u4e00-\u9fff\u30050-9０-９]+|[a-zA-ZＡ-Ｚａ-ｚ]+|[\u30A0-\u30FF]+)\[([^\]]+)\]',
    );
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      // 提取匹配之前的纯文本
      if (match.start > index) {
        final plainText = text.substring(index, match.start);
        if (plainText.isNotEmpty) {
          result.add(RubyTextData(plainText));
        }
      }

      // 提取带有注音的汉字部分
      final baseText = match.group(1);
      final furigana = match.group(2);

      if (baseText != null && furigana != null) {
        result.add(RubyTextData(baseText, ruby: furigana));
      }

      index = match.end;
    }

    // 提取最后剩余的纯文本
    if (index < text.length) {
      final tail = text.substring(index);
      if (tail.isNotEmpty) {
        result.add(RubyTextData(tail));
      }
    }

    return result;
  }
}
