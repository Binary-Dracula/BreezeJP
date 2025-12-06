import 'package:flutter/material.dart';
import '../../../data/models/word_detail.dart';
import 'example_item.dart';

/// 例句区
/// 包含多个例句条目
class WordExamplesSection extends StatelessWidget {
  final List<ExampleSentenceWithAudio> examples;

  const WordExamplesSection({super.key, required this.examples});

  @override
  Widget build(BuildContext context) {
    if (examples.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '例句',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(
              examples.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == examples.length - 1 ? 0 : 12,
                ),
                child: ExampleItem(example: examples[index], order: index + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
