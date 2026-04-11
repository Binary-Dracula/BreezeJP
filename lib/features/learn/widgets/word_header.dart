import 'package:flutter/material.dart';
import '../../../data/models/word_detail.dart';

/// 单词头部信息（2.0 — 对齐新 Word 模型）
class WordHeader extends StatelessWidget {
  final WordDetail wordDetail;

  const WordHeader({super.key, required this.wordDetail});

  @override
  Widget build(BuildContext context) {
    final word = wordDetail.word;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (word.reading.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            word.reading,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      if (word.romaji?.isNotEmpty == true)
                        Text(
                          word.romaji!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (word.partOfSpeech.isNotEmpty)
                  _Tag(
                    label: word.partOfSpeech,
                    color: theme.colorScheme.primary,
                  ),
                if (word.pitchAccent?.isNotEmpty == true)
                  _Tag(
                    label: '音調 ${word.pitchAccent}',
                    color: theme.colorScheme.secondary,
                  ),
                if (word.jlptLevel?.isNotEmpty == true)
                  _Tag(
                    label: word.jlptLevel!.toUpperCase(),
                    color: _jlptColor(word.jlptLevel!),
                  ),
                if (word.transitivity?.isNotEmpty == true)
                  _Tag(
                    label: word.transitivity!,
                    color: Colors.indigo,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _jlptColor(String level) {
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

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
