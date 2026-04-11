import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../../../data/models/word_detail.dart';

/// 释义区（2.0 — 使用 WordRichContent.meanings）
class WordMeaningsSection extends StatelessWidget {
  final WordRichContent richContent;

  const WordMeaningsSection({super.key, required this.richContent});

  @override
  Widget build(BuildContext context) {
    final meanings = richContent.meanings;
    if (meanings.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.wordDefinition,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(meanings.length, (index) {
              final m = meanings[index];
              final meaning = m['meaning'] as String? ?? '';
              final pos = m['part_of_speech'] as String?;
              final notes = m['notes'] as String?;
              return _MeaningItem(
                order: index + 1,
                meaning: meaning,
                partOfSpeech: pos,
                notes: notes,
                theme: theme,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MeaningItem extends StatelessWidget {
  final int order;
  final String meaning;
  final String? partOfSpeech;
  final String? notes;
  final ThemeData theme;

  const _MeaningItem({
    required this.order,
    required this.meaning,
    this.partOfSpeech,
    this.notes,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$order',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (partOfSpeech?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      partOfSpeech!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                Text(
                  meaning,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notes?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
