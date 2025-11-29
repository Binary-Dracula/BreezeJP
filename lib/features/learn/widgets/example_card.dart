import 'package:flutter/material.dart';
import '../../../core/widgets/custom_ruby_text.dart';
import '../../../data/models/word_detail.dart';
import 'audio_play_button.dart';

/// 例句卡片组件
/// 显示例句（带假名注音）、翻译和音频播放按钮
class ExampleCard extends StatelessWidget {
  final ExampleSentenceWithAudio example;

  const ExampleCard({super.key, required this.example});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = example.sentence;
    final audio = example.audio;
    final audioSource = audio?.audioUrl ?? audio?.audioFilename;

    // 优先使用 furigana，如果没有则使用原文
    var displayText = sentence.sentenceFurigana?.isNotEmpty == true
        ? sentence.sentenceFurigana!
        : sentence.sentenceJp;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 例句（带假名注音）和音频按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: JapaneseSentence(text: displayText)),
                if (audioSource != null)
                  AudioPlayButton(audioSource: audioSource, size: 28),
              ],
            ),
            // 翻译
            if (sentence.translationCn != null &&
                sentence.translationCn!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  sentence.translationCn!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
