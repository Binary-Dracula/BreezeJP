import 'package:flutter/material.dart';
import 'package:ruby_text/ruby_text.dart';

/// 日语例句组件
/// 支持假名注音和高亮显示
///
/// 解析格式: 妹[いもうと]は<b>高校[こうこう]</b>に通[かよ]っています
/// - 汉字[假名]: 显示假名注音
/// - <b>...</b>: 高亮显示
class JapaneseSentence extends StatelessWidget {
  const JapaneseSentence({
    super.key,
    required this.text,
    this.fontSize = 18,
    this.rubyFontSize = 11,
    this.textColor,
    this.highlightColor,
    this.rubyColor,
  });

  /// 带注音格式的日语文本
  final String text;

  /// 主文本字号
  final double fontSize;

  /// 注音字号
  final double rubyFontSize;

  /// 文本颜色（默认使用主题色）
  final Color? textColor;

  /// 高亮颜色（默认使用主题 primary 色）
  final Color? highlightColor;

  /// 注音颜色（默认使用主题色 60% 透明度）
  final Color? rubyColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rubyDataList = _parseFuriganaText(text, theme);

    return RubyText(
      rubyDataList,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor ?? theme.colorScheme.onSurface,
      ),
      rubyStyle: TextStyle(
        fontSize: rubyFontSize,
        color: rubyColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  List<RubyTextData> _parseFuriganaText(String input, ThemeData theme) {
    return _parseSegmentToRubyTextData(
      input,
      isBoldContext: false,
      theme: theme,
    );
  }

  List<RubyTextData> _parseSegmentToRubyTextData(
    String segment, {
    required bool isBoldContext,
    required ThemeData theme,
  }) {
    final List<RubyTextData> result = [];
    int index = 0;

    // 正则：匹配 <b>...</b> 或 汉字+[ruby]
    // 汉字范围包含：CJK统一汉字 + 々（重复符号）
    final pattern = RegExp(
      r'<b>(.*?)<\/b>' // group1: bold text
      r'|([\u4e00-\u9fff\u3005]+)\[([^\]]+)\]', // group2: 汉字+々, group3: ruby
      dotAll: true,
    );

    final matches = pattern.allMatches(segment);

    for (final match in matches) {
      // 处理匹配前的普通文本
      if (match.start > index) {
        final plainText = segment.substring(index, match.start);
        if (plainText.isNotEmpty) {
          result.add(
            RubyTextData(
              plainText,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
                color: isBoldContext
                    ? (highlightColor ?? theme.colorScheme.primary)
                    : (textColor ?? theme.colorScheme.onSurface),
              ),
            ),
          );
        }
      }

      // Case 1: <b>...</b>
      final boldText = match.group(1);
      if (boldText != null) {
        final innerTokens = _parseSegmentToRubyTextData(
          boldText,
          isBoldContext: true,
          theme: theme,
        );
        result.addAll(innerTokens);
        index = match.end;
        continue;
      }

      // Case 2: 汉字[ruby]
      final base = match.group(2);
      final ruby = match.group(3);
      if (base != null && ruby != null) {
        result.add(
          RubyTextData(
            base,
            ruby: ruby,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
              color: isBoldContext
                  ? (highlightColor ?? theme.colorScheme.primary)
                  : (textColor ?? theme.colorScheme.onSurface),
            ),
            rubyStyle: TextStyle(
              fontSize: rubyFontSize,
              color:
                  rubyColor ??
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        );
        index = match.end;
      }
    }

    // 处理最后剩余的文本
    if (index < segment.length) {
      final tail = segment.substring(index);
      if (tail.isNotEmpty) {
        result.add(
          RubyTextData(
            tail,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBoldContext ? FontWeight.bold : FontWeight.normal,
              color: isBoldContext
                  ? (highlightColor ?? theme.colorScheme.primary)
                  : (textColor ?? theme.colorScheme.onSurface),
            ),
          ),
        );
      }
    }

    return result;
  }
}
