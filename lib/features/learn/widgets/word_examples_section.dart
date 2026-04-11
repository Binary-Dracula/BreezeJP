import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../../../data/models/word_detail.dart';

/// 例句区（2.0 — 使用 WordExample 模型）
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
                  l10n.examples,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(examples.length, (index) {
              final ex = examples[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == examples.length - 1 ? 0 : 16,
                ),
                child: _ExampleItem(
                  order: index + 1,
                  japanese: ex.japanese,
                  chinese: ex.chinese,
                  level: ex.level,
                  theme: theme,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExampleItem extends StatelessWidget {
  final int order;
  final String japanese;
  final String chinese;
  final String level;
  final ThemeData theme;

  const _ExampleItem({
    required this.order,
    required this.japanese,
    required this.chinese,
    required this.level,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$order',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    japanese,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chinese,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
