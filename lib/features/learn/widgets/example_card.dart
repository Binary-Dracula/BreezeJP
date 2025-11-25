import 'package:flutter/material.dart';
import 'package:ruby_text/ruby_text.dart';
import '../../../data/models/word_detail.dart';

/// 例句卡片组件
class ExampleCard extends StatelessWidget {
  final ExampleSentenceWithAudio example;
  final int index;
  final bool isPlaying;
  final VoidCallback onPlayAudio;

  const ExampleCard({
    super.key,
    required this.example,
    required this.index,
    required this.isPlaying,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = example.sentence;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 例句标题
            Row(
              children: [
                Icon(
                  Icons.format_quote,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '例句 ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (example.audio != null)
                  IconButton(
                    onPressed: onPlayAudio,
                    icon: Icon(
                      isPlaying ? Icons.stop_circle : Icons.play_circle,
                      color: theme.colorScheme.primary,
                    ),
                    iconSize: 28,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 日文例句 - 使用 ruby_text 显示假名注音
            if (sentence.sentenceFurigana != null)
              _buildRubyText(sentence.sentenceFurigana!, theme)
            else
              Text(
                sentence.sentenceJp,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),

            // 中文翻译
            if (sentence.translationCn != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.translate,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sentence.translationCn!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建带假名注音的文本
  /// 解析格式: 妹[いもうと]は<b>高校[こうこう]</b>に通[かよ]っています
  Widget _buildRubyText(String furiganaText, ThemeData theme) {
    final rubyDataList = _parseFuriganaText(furiganaText, theme);

    return RubyText(
      rubyDataList,
      style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
      rubyStyle: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  List<RubyTextData> _parseFuriganaText(String input, ThemeData theme) {
    final tokens = _parseSegmentToRubyTextData(
      input,
      isBoldContext: false,
      theme: theme,
    );

    return tokens;
  }

  List<RubyTextData> _parseSegmentToRubyTextData(
    String segment, {
    required bool isBoldContext,
    required ThemeData theme,
  }) {
    final List<RubyTextData> result = [];
    int index = 0;

    // 正则：匹配 <b>...</b> 或 汉字+[ruby]
    // 关键：[\u4e00-\u9fff]+ 匹配一个或多个汉字
    final pattern = RegExp(
      r'<b>(.*?)<\/b>' // group1: bold text
      r'|([\u4e00-\u9fff]+)\[([^\]]+)\]', // group2: 汉字, group3: ruby
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

      // ---------- Case 1: <b>...</b>
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

      // ---------- Case 2: 汉字[ruby]
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

    return result;
  }
}
