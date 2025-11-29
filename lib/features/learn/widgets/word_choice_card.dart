import 'package:flutter/material.dart';
import '../../../data/models/word_choice.dart';

/// 单词选择卡片组件
/// 用于初始选择页展示单词选项
class WordChoiceCard extends StatelessWidget {
  final WordChoice wordChoice;
  final VoidCallback onTap;

  const WordChoiceCard({
    super.key,
    required this.wordChoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = wordChoice.word;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧：单词和假名
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词
                    Text(
                      word.word,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 假名
                    if (word.furigana != null && word.furigana!.isNotEmpty)
                      Text(
                        word.furigana!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // 释义
                    if (wordChoice.primaryMeaning != null)
                      Text(
                        wordChoice.primaryMeaning!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：JLPT 等级标签和箭头
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (word.jlptLevel != null)
                    _JlptLevelBadge(level: word.jlptLevel!),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// JLPT 等级标签
class _JlptLevelBadge extends StatelessWidget {
  final String level;

  const _JlptLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'n5':
        return Colors.green;
      case 'n4':
        return Colors.teal;
      case 'n3':
        return Colors.blue;
      case 'n2':
        return Colors.orange;
      case 'n1':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
