import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../../../core/widgets/common_example_item.dart';
import '../../../data/models/word_detail.dart';

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
              final sentence = ex.sentence;
              final audio = ex.audio;
              final audioSource = audio?.audioUrl ?? audio?.audioFilename;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == examples.length - 1 ? 0 : 16,
                ),
                child: CommonExampleItem(
                  order: index + 1,
                  data: ExampleDisplayData(
                    japanese: sentence.sentenceFurigana?.isNotEmpty == true
                        ? sentence.sentenceFurigana!
                        : sentence.sentenceJp,
                    translation: sentence.translationCn,
                    audioSource: audioSource,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
