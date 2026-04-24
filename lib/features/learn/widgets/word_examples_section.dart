import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../../../core/widgets/common_example_item.dart';
import '../../../data/models/word_detail.dart';

/// 例句区（2.0 — 使用 CommonExampleItem 保持简洁一致）
class WordExamplesSection extends StatelessWidget {
  final List<WordExample> examples;

  const WordExamplesSection({super.key, required this.examples});

  @override
  Widget build(BuildContext context) {
    if (examples.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  l10n.examples,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(examples.length, (index) {
              final example = examples[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == examples.length - 1 ? 0 : 16,
                ),
                child: _ExampleItem(example: example, order: index + 1),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExampleItem extends StatelessWidget {
  final WordExample example;
  final int order;

  const _ExampleItem({required this.example, required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommonExampleItem(
          order: order,
          primaryColor: const Color(0xFF6366F1),
          data: ExampleDisplayData(
            japanese: example.japanese,
            translation: example.chinese,
          ),
        ),
      ],
    );
  }
}
