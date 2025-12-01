import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/kana_detail.dart';
import '../pages/kana_stroke_practice_page.dart';
import '../state/kana_chart_state.dart';

/// 五十音网格组件
/// 按行列展示假名，清晰显示行和段
class KanaGrid extends ConsumerWidget {
  final List<KanaLetterWithState> kanaLetters;
  final KanaDisplayMode displayMode;
  final String kanaType;

  const KanaGrid({
    super.key,
    required this.kanaLetters,
    required this.displayMode,
    required this.kanaType,
  });

  // ==================== 常量定义 ====================

  /// 类型常量
  static const String typeSeion = '清音';
  static const String typeDakuon = '濁音';
  static const String typeHandakuon = '半濁音';
  static const String typeYouon = '拗音';
  static const String typeGairaion = '外来音';

  /// 元音列标题
  static const List<String> _vowelHeaders = ['あ段', 'い段', 'う段', 'え段', 'お段'];

  /// 元音顺序
  static const List<String> _vowelOrder = ['a', 'i', 'u', 'e', 'o'];

  /// 清音行顺序
  static const List<String> _seionRowOrder = [
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

  /// 濁音行顺序
  static const List<String> _dakuonRowOrder = ['ga', 'za', 'da', 'ba'];

  /// 半濁音行顺序
  static const List<String> _handakuonRowOrder = ['pa'];

  /// 拗音行顺序
  static const List<String> _youonRowOrder = [
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

  /// 行标签映射
  static const Map<String, String> _rowLabels = {
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

  /// 特殊行标识
  static const String _specialGroup = 'special';

  // ==================== 构建方法 ====================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 根据类型选择不同的布局
    switch (kanaType) {
      case typeYouon:
        return _buildYouonGrid(context, ref);
      case typeGairaion:
        return _buildExtendedGrid(context, ref);
      default:
        // 清音、濁音、半濁音 使用标准网格
        return _buildStandardGrid(context, ref);
    }
  }

  /// 标准五十音网格（清音、浊音、半浊音）
  Widget _buildStandardGrid(BuildContext context, WidgetRef ref) {
    // 只有清音显示行和段标题
    final showHeaders = kanaType == typeSeion;

    // 非清音使用简单网格布局
    if (!showHeaders) {
      return _buildSimpleGrid(context, ref);
    }

    // 清音使用带标题的布局
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
        _buildColumnHeaders(_vowelHeaders),
        const SizedBox(height: 8),
        // 每一行
        ...sortedGroups.map((group) {
          final kanaInRow = groupedByRow[group]!;
          // 特殊行单独处理
          if (group == _specialGroup) {
            return _buildSpecialRow(
              context,
              ref,
              _getRowLabel(group),
              kanaInRow,
            );
          }
          return _buildKanaRow(context, ref, _getRowLabel(group), kanaInRow, 5);
        }),
      ],
    );
  }

  /// 简单网格布局（浊音、半浊音等无标题）
  Widget _buildSimpleGrid(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: kanaLetters.length,
      itemBuilder: (context, index) {
        return _buildKanaCell(context, ref, kanaLetters[index]);
      },
    );
  }

  /// 拗音网格
  Widget _buildYouonGrid(BuildContext context, WidgetRef ref) {
    // 按行分组
    final groupedByRow = <String, List<KanaLetterWithState>>{};
    for (final kana in kanaLetters) {
      final group = kana.letter.kanaGroup ?? 'other';
      groupedByRow.putIfAbsent(group, () => []).add(kana);
    }

    final sortedGroups = _youonRowOrder
        .where((g) => groupedByRow.containsKey(g))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 每一行（不显示行和列标题）
        ...sortedGroups.map((group) {
          final kanaInRow = groupedByRow[group]!;
          return _buildYouonRow(context, ref, null, kanaInRow);
        }),
      ],
    );
  }

  /// 特殊假名网格（外来音）
  Widget _buildExtendedGrid(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: kanaLetters.length,
      itemBuilder: (context, index) {
        return _buildKanaCell(context, ref, kanaLetters[index]);
      },
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
    WidgetRef ref,
    String? rowLabel,
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
          // 行标题（可选）
          if (rowLabel != null)
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
                  ? _buildKanaCell(context, ref, kana)
                  : const SizedBox.shrink(),
            );
          }),
        ],
      ),
    );
  }

  /// 构建特殊行（ん、を 等不规则假名）
  Widget _buildSpecialRow(
    BuildContext context,
    WidgetRef ref,
    String? rowLabel,
    List<KanaLetterWithState> kanaInRow,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 行标题（可选）
          if (rowLabel != null)
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
          // 特殊假名直接显示，不按元音排列
          ...kanaInRow.map((kana) {
            return Expanded(child: _buildKanaCell(context, ref, kana));
          }),
          // 填充空位保持对齐
          ...List.generate(5 - kanaInRow.length, (_) {
            return const Expanded(child: SizedBox.shrink());
          }),
        ],
      ),
    );
  }

  /// 构建一行拗音
  Widget _buildYouonRow(
    BuildContext context,
    WidgetRef ref,
    String? rowLabel,
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
          // 行标题（可选）
          if (rowLabel != null)
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
                  ? _buildKanaCell(context, ref, kana)
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
    WidgetRef ref,
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

    final wrappedCell = GestureDetector(
      onTap: () => _onKanaTap(context, ref, kana),
      child: cell,
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: wrappedCell);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      child: AspectRatio(aspectRatio: 1, child: wrappedCell),
    );
  }

  /// 处理假名点击
  void _onKanaTap(
    BuildContext context,
    WidgetRef _ref,
    KanaLetterWithState kana,
  ) {
    final index = kanaLetters.indexWhere(
      (item) => item.letter.id == kana.letter.id,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KanaStrokePracticePage(
          kanaLetters: kanaLetters,
          initialIndex: index >= 0 ? index : 0,
          displayMode: displayMode,
        ),
      ),
    );
  }

  // ==================== 辅助方法 ====================

  /// 获取行顺序
  List<String> _getRowOrder(String type) {
    switch (type) {
      case typeSeion:
        return _seionRowOrder;
      case typeDakuon:
        return _dakuonRowOrder;
      case typeHandakuon:
        return _handakuonRowOrder;
      default:
        return [];
    }
  }

  /// 获取行标签
  String _getRowLabel(String group) => _rowLabels[group] ?? group;

  /// 获取元音索引
  int _getVowelIndex(String? vowel) {
    if (vowel == null) return -1;
    return _vowelOrder.indexOf(vowel);
  }
}
