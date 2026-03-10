import 'package:flutter/material.dart';

/// 乱序拼写选项区域
class ReviewSpellingOptions extends StatefulWidget {
  final List<String> options;
  final String correctSpelling;
  final bool hasMistake;
  final ValueChanged<String> onSelect; // 返回用户拼出的完整结果以供验证

  const ReviewSpellingOptions({
    super.key,
    required this.options,
    required this.correctSpelling,
    required this.hasMistake,
    required this.onSelect,
  });

  @override
  State<ReviewSpellingOptions> createState() => _ReviewSpellingOptionsState();
}

class _ReviewSpellingOptionsState extends State<ReviewSpellingOptions> {
  // 当前放置到槽位内的选中的索引列表
  final List<int> _selectedIndices = [];
  bool _isWrong = false;

  int get _targetLength => widget.correctSpelling.split('').length;

  @override
  void didUpdateWidget(covariant ReviewSpellingOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.correctSpelling != widget.correctSpelling) {
      _selectedIndices.clear();
      _isWrong = false;
    }
    if (widget.hasMistake && !oldWidget.hasMistake) {
      // 从外部注入的错误状态
      setState(() {
        _isWrong = true;
      });
    }
  }

  void _handleTapOption(int index) {
    if (_selectedIndices.contains(index)) return; // 已经上槽了

    // 如果方框已经填满，再次点击新的假名，则清空重新从第一个方框开始填
    if (_selectedIndices.length >= _targetLength) {
      setState(() {
        _selectedIndices.clear();
        _isWrong = false;
        _selectedIndices.add(index);
      });
      return;
    }

    setState(() {
      _selectedIndices.add(index);
      _isWrong = false; // 清除错误状态
    });

    if (_selectedIndices.length == _targetLength) {
      // 填满了，自动触发验证
      final currentAnswer = _selectedIndices
          .map((i) => widget.options[i])
          .join('');
      // 延迟一点让用户看到字放上去了
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.onSelect(currentAnswer);
        }
      });
    }
  }

  void _handleTapSlot(int indexWithinSelected) {
    // 允许用户点击已上槽的字母把它拿下来
    setState(() {
      _selectedIndices.removeAt(indexWithinSelected);
      _isWrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 目标槽位区域 (下划线/方块)
        _buildSlotsArea(),

        const SizedBox(height: 32),

        // 可选字母区域 (乱序气泡)
        _buildOptionsArea(),
      ],
    );
  }

  Widget _buildSlotsArea() {
    final length = _targetLength;
    final correctChars = widget.correctSpelling.split('');

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(length, (index) {
        final hasChar = index < _selectedIndices.length;
        final char = hasChar ? widget.options[_selectedIndices[index]] : '';
        final expectedChar = index < correctChars.length
            ? correctChars[index]
            : '';

        // 只有整体判错(_isWrong)且当前格子被填入且跟正确答案对应的字不同，才会标红
        final isThisBoxWrong = _isWrong && hasChar && char != expectedChar;

        return GestureDetector(
          onTap: hasChar ? () => _handleTapSlot(index) : null,
          child: Container(
            width: 48,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasChar
                  ? (isThisBoxWrong
                        ? Colors.red[50]
                        : const Color(0xFF6C63FF).withValues(alpha: 0.1))
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasChar
                    ? (isThisBoxWrong ? Colors.red : const Color(0xFF6C63FF))
                    : Colors.grey[300]!,
                width: hasChar ? 2 : 1.5,
              ),
            ),
            child: Text(
              char,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isThisBoxWrong ? Colors.red : const Color(0xFF2D3142),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOptionsArea() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(widget.options.length, (index) {
        final isSelected = _selectedIndices.contains(index);
        final char = widget.options[index];

        return GestureDetector(
          onTap: isSelected ? null : () => _handleTapOption(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey[100] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[200]!,
              ),
              boxShadow: isSelected
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Text(
              char,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.grey[300] : const Color(0xFF2D3142),
              ),
            ),
          ),
        );
      }),
    );
  }
}
