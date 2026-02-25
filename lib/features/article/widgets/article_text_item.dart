import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/furigana_parser.dart';
import 'package:ruby_text/ruby_text.dart';
import '../../../data/models/article/article_item.dart';
import '../controller/article_audio_controller.dart';

class ArticleTextItem extends ConsumerWidget {
  final ArticleItem item;
  final bool isHighlight;

  const ArticleTextItem({
    super.key,
    required this.item,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(articleAudioProvider);
    final showFurigana = state.showFurigana;
    final showTranslation = state.showTranslation;

    final rubyDataList = FuriganaParser.parse(item.text);

    // 字体样式设置
    double baseFontSize = 18.0;
    Color textColor = isHighlight
        ? Colors.black
        : Colors.black87.withValues(alpha: 0.85);
    FontWeight fontWeight = isHighlight ? FontWeight.w600 : FontWeight.normal;

    // 判断是否包含假名注音
    final hasFurigana = rubyDataList.any((d) => d.ruby != null);

    Widget textWidget;

    if (hasFurigana) {
      // 有假名 → 使用 RubyText 渲染注音
      textWidget = RubyText(
        rubyDataList,
        style: TextStyle(
          fontSize: baseFontSize,
          fontWeight: fontWeight,
          color: textColor,
          height: 2.0,
          letterSpacing: 0.5,
        ),
        rubyStyle: TextStyle(
          fontSize: baseFontSize * 0.5,
          color: showFurigana
              ? textColor.withValues(alpha: 0.8)
              : Colors.transparent,
        ),
        textAlign: TextAlign.left,
      );
    } else {
      // 无假名 → 使用普通 Text，自然左对齐
      final plainText = rubyDataList.map((d) => d.text).join();
      textWidget = Text(
        plainText,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: baseFontSize,
          fontWeight: fontWeight,
          color: textColor,
          height: 2.0,
          letterSpacing: 0.5,
        ),
      );
    }

    // 翻译文本
    String translationText = item.translation;
    if (translationText.isEmpty) {
      translationText = "(暂无翻译数据，这是 Demo 占位符帮助观察两行排版。)";
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textWidget,
        const SizedBox(height: 2),
        Opacity(
          opacity: showTranslation ? 1.0 : 0.0,
          child: Text(
            translationText,
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

    // 统一 padding，高亮只改变背景样式，不改变尺寸
    content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: isHighlight
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: content,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final notifier = ref.read(articleAudioProvider.notifier);
        notifier.setActiveIndex(item.index);
      },
      child: content,
    );
  }
}
