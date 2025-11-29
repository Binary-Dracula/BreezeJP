import 'package:flutter/material.dart';
import '../../../data/models/kana_detail.dart';
import '../state/kana_chart_state.dart';

/// 五十音网格组件
/// 按行列展示假名，清晰显示行和段
class KanaGrid extends StatelessWidget {
  final List<KanaLetterWithState> kanaLetters;
  final KanaDisplayMode displayMode;
  final String kanaType;

  const KanaGrid({
    super.key,
    required this.kanaLetters,
    required this.displayMode,
    required this.kanaType,
  });

  @override
  Widget build(BuildContext context) {
    // 根据类型选择不同的布局
    switch (kanaType) {
      case 'youon':
        return _buildYouonGrid(context);
      case 'extended':
        return _buildExtendedGrid(context);
      default:
        return _buildStandardGrid(context);
    }
  }

  /// 标准五十音网格（清音、浊音、半浊音）
  Widget _buildStandardGrid(BuildContext context) {
    // 元音列标题
    const vowels = ['あ段', 'い段', 'う段', 'え段', 'お段'];

    // 按行分组
    final groupedByRow = <String, List<KanaLetterWithState>>{};
    for (final kana in kanaLetters) {
      final group = kana.letter.kanaGroup ?? 'other';
      groupedByRow.putIfAbsent(group, () => []).add(kana);
    }

    // 获取行顺序
    final rowOrder = _getRowOrder(kanaType);
    final sortedGroups = rowOrder
        .where((g) => groupedByRow.containsKey(g))
        .toList();

    // 添加未在预定义顺序中的行
    for (final group in groupedByRow.keys) {
      if (!sortedGroups.contains(group)) {
        sortedGroups.add(group);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 列标题（段）
        _buildColumnHeaders(vowels),
        const SizedBox(height: 8),
        // 每一行
        ...sortedGroups.map((group) {
          final kanaInRow = groupedByRow[group]!;
          return _buildKanaRow(context, _getRowLabel(group), kanaInRow, 5);
        }),
      ],
    );
  }

  /// 拗音网格
  Widget _buildYouonGrid(BuildContext context) {
    // 拗音列标题
    const youonVowels = ['ゃ列', 'ゅ列', 'ょ列'];

    // 按行分组
    final groupedByRow = <String, List<KanaLetterWithState>>{};
    for (final kana in kanaLetters) {
      final group = kana.letter.kanaGroup ?? 'other';
      groupedByRow.putIfAbsent(group, () => []).add(kana);
    }

    // 拗音行顺序
    final rowOrder = [
      'kya',
      'sha',
      'cha',
      'nya',
      'hya',
      'mya',
      'rya',
      'gya',
      'ja',
      'bya',
      'pya',
    ];
    final sortedGroups = rowOrder
        .where((g) => groupedByRow.containsKey(g))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 列标题
        _buildColumnHeaders(youonVowels),
        const SizedBox(height: 8),
        // 每一行
        ...sortedGroups.map((group) {
          final kanaInRow = groupedByRow[group]!;
          return _buildYouonRow(context, _getYouonRowLabel(group), kanaInRow);
        }),
      ],
    );
  }

  /// 特殊假名网格
  Widget _buildExtendedGrid(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kanaLetters.map((kana) {
        return _buildKanaCell(context, kana, size: 72);
      }).toList(),
    );
  }

  /// 列标题
  Widget _buildColumnHeaders(List<String> headers) {
    return Row(
      children: [
        // 行标题占位
        const SizedBox(width: 56),
        // 列标题
        ...headers.map((header) {
          return Expanded(
            child: Center(
              child: Text(
                header,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 构建一行假名（标准五十音）
  Widget _buildKanaRow(
    BuildContext context,
    String rowLabel,
    List<KanaLetterWithState> kanaInRow,
    int columnCount,
  ) {
    // 按元音排序
    final sortedKana = List<KanaLetterWithState?>.filled(columnCount, null);
    for (final kana in kanaInRow) {
      final vowelIndex = _getVowelIndex(kana.letter.vowel);
      if (vowelIndex >= 0 && vowelIndex < columnCount) {
        sortedKana[vowelIndex] = kana;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 行标题
          SizedBox(
            width: 56,
            child: Text(
              rowLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 假名格子
          ...sortedKana.map((kana) {
            return Expanded(
              child: kana != null
                  ? _buildKanaCell(context, kana)
                  : const SizedBox.shrink(),
            );
          }),
        ],
      ),
    );
  }

  /// 构建一行拗音
  Widget _buildYouonRow(
    BuildContext context,
    String rowLabel,
    List<KanaLetterWithState> kanaInRow,
  ) {
    // 拗音按 a, u, o 排序
    final sortedKana = List<KanaLetterWithState?>.filled(3, null);
    for (final kana in kanaInRow) {
      final vowel = kana.letter.vowel;
      if (vowel == 'a') {
        sortedKana[0] = kana;
      } else if (vowel == 'u') {
        sortedKana[1] = kana;
      } else if (vowel == 'o') {
        sortedKana[2] = kana;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 行标题
          SizedBox(
            width: 56,
            child: Text(
              rowLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 假名格子
          ...sortedKana.map((kana) {
            return Expanded(
              child: kana != null
                  ? _buildKanaCell(context, kana)
                  : const SizedBox.shrink(),
            );
          }),
        ],
      ),
    );
  }

  /// 单个假名格子
  Widget _buildKanaCell(
    BuildContext context,
    KanaLetterWithState kana, {
    double? size,
  }) {
    final displayText = displayMode == KanaDisplayMode.hiragana
        ? kana.letter.hiragana
        : kana.letter.katakana;

    final isLearned = kana.isLearned;

    final cell = Container(
      decoration: BoxDecoration(
        color: isLearned
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLearned
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 假名
          Text(
            displayText ?? '',
            style: TextStyle(
              fontSize: size != null ? 28 : 24,
              fontWeight: FontWeight.w500,
              color: isLearned
                  ? Theme.of(context).primaryColor
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          // 罗马音
          Text(
            kana.letter.romaji ?? '',
            style: TextStyle(
              fontSize: 10,
              color: isLearned
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.7)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: cell);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      child: AspectRatio(aspectRatio: 1, child: cell),
    );
  }

  /// 获取行顺序
  List<String> _getRowOrder(String type) {
    switch (type) {
      case 'basic':
        return [
          'a',
          'ka',
          'sa',
          'ta',
          'na',
          'ha',
          'ma',
          'ya',
          'ra',
          'wa',
          'special',
        ];
      case 'dakuon':
        return ['ga', 'za', 'da', 'ba'];
      case 'handakuon':
        return ['pa'];
      default:
        return [];
    }
  }

  /// 获取行标签
  String _getRowLabel(String group) {
    const labels = {
      'a': 'あ行',
      'ka': 'か行',
      'sa': 'さ行',
      'ta': 'た行',
      'na': 'な行',
      'ha': 'は行',
      'ma': 'ま行',
      'ya': 'や行',
      'ra': 'ら行',
      'wa': 'わ行',
      'special': '特殊',
      'ga': 'が行',
      'za': 'ざ行',
      'da': 'だ行',
      'ba': 'ば行',
      'pa': 'ぱ行',
    };
    return labels[group] ?? group;
  }

  /// 获取拗音行标签
  String _getYouonRowLabel(String group) {
    const labels = {
      'kya': 'きゃ行',
      'sha': 'しゃ行',
      'cha': 'ちゃ行',
      'nya': 'にゃ行',
      'hya': 'ひゃ行',
      'mya': 'みゃ行',
      'rya': 'りゃ行',
      'gya': 'ぎゃ行',
      'ja': 'じゃ行',
      'bya': 'びゃ行',
      'pya': 'ぴゃ行',
    };
    return labels[group] ?? group;
  }

  /// 获取元音索引
  int _getVowelIndex(String? vowel) {
    if (vowel == null) return -1;
    const vowels = ['a', 'i', 'u', 'e', 'o'];
    return vowels.indexOf(vowel);
  }
}
