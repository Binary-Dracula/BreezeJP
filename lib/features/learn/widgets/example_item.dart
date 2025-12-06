import 'package:flutter/material.dart';
import '../../../core/widgets/custom_ruby_text.dart';
import '../../../data/models/word_detail.dart';
import 'audio_play_button.dart';

/// 单条例句
/// 展示日文（含 ruby）、中文翻译与音频播放
class ExampleItem extends StatelessWidget {
  final ExampleSentenceWithAudio example;
  final int order;

  const ExampleItem({super.key, required this.example, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = example.sentence;
    final audio = example.audio;
    final audioSource = audio?.audioUrl ?? audio?.audioFilename;

    final displayText = sentence.sentenceFurigana?.isNotEmpty == true
        ? sentence.sentenceFurigana!
        : sentence.sentenceJp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderBadge(order: order, theme: theme),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JapaneseSentence(
                text: displayText,
                fontSize: 18,
                rubyFontSize: 11,
              ),
              if (sentence.translationCn?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sentence.translationCn!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              if (sentence.notes?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sentence.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (audioSource != null) ...[
          const SizedBox(width: 8),
          AudioPlayButton(audioSource: audioSource, size: 28),
        ],
      ],
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final int order;
  final ThemeData theme;

  const _OrderBadge({required this.order, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
