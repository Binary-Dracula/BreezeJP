import 'package:flutter/material.dart';

/// 自定义 Ruby Text 组件
/// 用于显示带假名注音的日文文本，假名居中对齐
class CustomRubyText extends StatelessWidget {
  final String base;
  final String? ruby;
  final TextStyle? baseStyle;
  final TextStyle? rubyStyle;
  final bool isBold;

  const CustomRubyText({
    super.key,
    required this.base,
    this.ruby,
    this.baseStyle,
    this.rubyStyle,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    if (ruby == null || ruby!.isEmpty) {
      // 没有假名，直接显示文本
      return Text(base, style: baseStyle);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 假名（上方）
        Text(ruby!, style: rubyStyle, textAlign: TextAlign.center),
        // 基础文本（下方）
        Text(base, style: baseStyle, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Ruby Text 行组件
/// 将多个 Ruby Text 组件排列在一行
class CustomRubyTextLine extends StatelessWidget {
  final List<CustomRubyTextData> data;
  final TextStyle? defaultBaseStyle;
  final TextStyle? defaultRubyStyle;

  const CustomRubyTextLine({
    super.key,
    required this.data,
    this.defaultBaseStyle,
    this.defaultRubyStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: data.map((item) {
        return CustomRubyText(
          base: item.base,
          ruby: item.ruby,
          baseStyle: item.baseStyle ?? defaultBaseStyle,
          rubyStyle: item.rubyStyle ?? defaultRubyStyle,
          isBold: item.isBold,
        );
      }).toList(),
    );
  }
}

/// Ruby Text 数据类
class CustomRubyTextData {
  final String base;
  final String? ruby;
  final TextStyle? baseStyle;
  final TextStyle? rubyStyle;
  final bool isBold;

  const CustomRubyTextData({
    required this.base,
    this.ruby,
    this.baseStyle,
    this.rubyStyle,
    this.isBold = false,
  });
}
