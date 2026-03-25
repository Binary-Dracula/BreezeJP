import 'package:flutter/foundation.dart';

/// 表示单个速查卡片数据条目
@immutable
class ReferenceItem {
  /// 主字符（比如：1, 百, 4時, 月曜日）
  final String character;

  /// 对应的假名发音
  final String kana;

  /// 罗马音或进一步的解释（可选）
  final String? romaji;

  /// 翻译（可选）
  final String? translation;

  /// 表示是否是特殊读音/变音，UI渲染时会被高亮标红
  final bool isIrregular;

  const ReferenceItem({
    required this.character,
    required this.kana,
    this.romaji,
    this.translation,
    this.isIrregular = false,
  });
}

/// 针对每一个大模块下的分组（比如按1-10分组，按百千分组）
@immutable
class ReferenceGroup {
  /// 分组标题
  final String title;

  /// 分组副标题（可选，用于描述量词用途等）
  final String? subtitle;

  /// 卡片列表
  final List<ReferenceItem> items;

  const ReferenceGroup({
    required this.title,
    this.subtitle,
    required this.items,
  });
}
