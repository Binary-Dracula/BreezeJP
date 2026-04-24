import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ruby_text/ruby_text.dart';

import '../../../core/utils/furigana_parser.dart';
import '../../../data/models/article/article_item.dart';
import '../../../data/models/article/article_word.dart';
import '../controller/article_audio_controller.dart';
import '../state/article_state.dart';

// ----------------------------------------------------------------------
// 文章句子组件（Wrap 布局 + 独立 ruby_text）
// ----------------------------------------------------------------------
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
    final notifier = ref.read(articleAudioProvider.notifier);
    final showFurigana =
        state.displayMode == ArticleDisplayMode.all ||
        state.displayMode == ArticleDisplayMode.furiganaOnly;
    final showTranslation =
        state.displayMode == ArticleDisplayMode.all ||
        state.displayMode == ArticleDisplayMode.translationOnly;

    // 基础样式
    const double baseFontSize = 18.0;
    const double rubyFontSize = 9.0;
    final Color textColor = isHighlight
        ? Colors.black
        : Colors.black87.withValues(alpha: 0.85);

    // 构建每个 word 的 widget 列表
    final wordWidgets = <Widget>[];
    for (int i = 0; i < item.words.length; i++) {
      final word = item.words[i];
      wordWidgets.add(
        _WordRubyWidget(
          word: word,
          fontSize: baseFontSize,
          rubyFontSize: rubyFontSize,
          textColor: textColor,
          showFurigana: showFurigana,
          onLongPress: word.isPunctuation
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  notifier.pauseAudio();
                  _showWordDetailSheet(context, word);
                },
        ),
      );
    }

    // 翻译文本
    final translationText = item.translation.isNotEmpty ? item.translation : '';

    // 日文文本 widget：优先用 words（新数据），否则 fallback 到 item.text（旧数据）
    Widget japaneseTextWidget;
    if (item.words.isNotEmpty) {
      // 新数据：Wrap 布局 + 独立 ruby_text
      japaneseTextWidget = Wrap(
        spacing: 0,
        runSpacing: 0,
        children: wordWidgets,
      );
    } else {
      // 旧数据 fallback：使用 FuriganaParser 解析 item.text
      final rubyDataList = FuriganaParser.parse(item.text);
      japaneseTextWidget = RubyText(
        rubyDataList,
        style: TextStyle(
          fontSize: baseFontSize,
          color: textColor,
          height: 2.0,
          letterSpacing: 0.5,
        ),
        rubyStyle: TextStyle(
          fontSize: rubyFontSize,
          color: showFurigana
              ? textColor.withValues(alpha: 0.7)
              : Colors.transparent,
        ),
        textAlign: TextAlign.left,
      );
    }

    // 句子内容
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        japaneseTextWidget,
        if (translationText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Opacity(
            opacity: showTranslation ? 1.0 : 0.0,
            child: Text(
              translationText,
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );

    // 统一 padding + 高亮背景（不改变高度）
    content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: isHighlight
          ? BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: content,
    );

    // 检查是否显示 A/B 角标
    Widget finalContent = content;
    if (state.currentMode == ArticleMode.abLoop) {
      final bool isA = state.loopStartIdx == item.index;
      final bool isB = state.loopEndIdx == item.index;

      if (isA || isB) {
        String badgeText;
        Color badgeColor;
        double badgeWidth;

        if (isA && isB) {
          badgeText = 'A/B';
          badgeColor = Colors.purple; // 组合色或紫色
          badgeWidth = 32;
        } else if (isA) {
          badgeText = 'A';
          badgeColor = Colors.green;
          badgeWidth = 20;
        } else {
          badgeText = 'B';
          badgeColor = Colors.red;
          badgeWidth = 20;
        }

        finalContent = Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            Positioned(
              right: 6,
              top: 2,
              child: Container(
                width: badgeWidth,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    // 句子级别手势：点击触发控制器统一路由逻辑
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        notifier.onSentenceTap(item.index);
      },
      child: finalContent,
    );
  }

  /// 长按单词 → 弹出半屏词详情（下滑消失）
  void _showWordDetailSheet(BuildContext context, ArticleWord word) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.15,
          maxChildSize: 0.7,
          expand: false,
          snap: true,
          snapSizes: const [0.15, 0.45],
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 拖拽手柄
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 表层形式（大字）
                      Text(
                        word.surfaceForm,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (word.furigana.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          word.furigana,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      // 词性信息
                      if (word.pos.isNotEmpty && word.pos != '*')
                        _DetailRow(label: '词性', value: word.pos),
                      if (word.posDetail1.isNotEmpty && word.posDetail1 != '*')
                        _DetailRow(label: '词性细分', value: word.posDetail1),
                      if (word.basicForm.isNotEmpty &&
                          word.basicForm != '*' &&
                          word.basicForm != word.surfaceForm)
                        _DetailRow(label: '基本形', value: word.basicForm),
                      if (word.reading != null && word.reading!.isNotEmpty)
                        _DetailRow(label: '读音', value: word.reading!),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 单个 word 的 Ruby Widget
// ----------------------------------------------------------------------
class _WordRubyWidget extends StatelessWidget {
  final ArticleWord word;
  final double fontSize;
  final double rubyFontSize;
  final Color textColor;
  final bool showFurigana;
  final VoidCallback? onLongPress;

  const _WordRubyWidget({
    required this.word,
    required this.fontSize,
    required this.rubyFontSize,
    required this.textColor,
    required this.showFurigana,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 解析 ruby_text 格式生成 RubyTextData 列表
    final rubyDataList = FuriganaParser.parse(word.rubyText);

    // 设置样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: textColor,
      height: 1.2,
    );

    final rubyStyle = TextStyle(
      fontSize: rubyFontSize,
      color: showFurigana && word.hasKanji
          ? textColor.withValues(alpha: 0.7)
          : Colors.transparent,
      height: 1.1,
    );

    // 为每个 RubyTextData 设置样式
    // 对于没有 ruby 注音的纯假名片段，添加透明占位 ruby，确保所有词纵向高度一致（底部对齐）
    // 注意：即使整个 word 含有汉字，其中的纯假名片段（如「考え方」中的「え」）
    // 也必须使用透明 ruby，避免假名上方错误显示假名注音
    final styledRubyData = rubyDataList.map((data) {
      final hasRuby = data.ruby != null && data.ruby!.isNotEmpty;
      return RubyTextData(
        data.text,
        ruby: hasRuby ? data.ruby : data.text,
        style: textStyle,
        rubyStyle: hasRuby && showFurigana && word.hasKanji
            ? rubyStyle
            : TextStyle(
                fontSize: rubyFontSize,
                color: Colors.transparent,
                height: 1.1,
              ),
      );
    }).toList();

    // 不在 RubyText widget 上设置全局 rubyStyle！
    // 因为 ruby_text 包的 copyWith 会用它覆盖所有 per-item 的 rubyStyle，
    // 导致纯假名片段的透明色被全局可见色覆盖。
    Widget rubyWidget = RubyText(styledRubyData, style: textStyle);

    // 标点符号不包裹 GestureDetector
    if (word.isPunctuation || onLongPress == null) {
      return rubyWidget;
    }

    // 使用 GestureDetector 接管长按手势，阻止事件冒泡到父级 Wrap
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: rubyWidget,
    );
  }
}

// ----------------------------------------------------------------------
// 词详情行
// ----------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
