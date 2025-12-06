import 'package:flutter/material.dart';
import '../../../data/models/word_detail.dart';
import 'audio_play_button.dart';

/// 单词头部信息
/// 展示单词、假名、发音按钮以及词性/JLPT 等基础标签
class WordHeader extends StatelessWidget {
  final WordDetail wordDetail;

  const WordHeader({super.key, required this.wordDetail});

  @override
  Widget build(BuildContext context) {
    final word = wordDetail.word;
    final primaryAudio = wordDetail.primaryAudio;
    final audioSource = primaryAudio?.audioUrl ?? primaryAudio?.audioFilename;
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
                      if (word.furigana?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            word.furigana!,
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
                if (audioSource != null)
                  AudioPlayButton(audioSource: audioSource, size: 40),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (word.partOfSpeech?.isNotEmpty == true)
                  _Tag(
                    label: word.partOfSpeech!,
                    color: theme.colorScheme.primary,
                  ),
                if (word.pitchAccent?.isNotEmpty == true)
                  _Tag(
                    label: '音调 ${word.pitchAccent}',
                    color: theme.colorScheme.secondary,
                  ),
                if (word.jlptLevel?.isNotEmpty == true)
                  _Tag(
                    label: word.jlptLevel!.toUpperCase(),
                    color: _jlptColor(word.jlptLevel!),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
