import 'package:flutter/material.dart';
import '../../../data/models/word_detail.dart';
import 'audio_play_button.dart';

/// 单词卡片组件
/// 显示单词的完整信息
class WordCard extends StatelessWidget {
  final WordDetail wordDetail;

  const WordCard({super.key, required this.wordDetail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = wordDetail.word;
    final meanings = wordDetail.meanings;
    final primaryAudio = wordDetail.audios.isNotEmpty
        ? wordDetail.audios.first.audioUrl ??
              wordDetail.audios.first.audioFilename
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 单词和音频按钮
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (primaryAudio != null)
                  AudioPlayButton(audioSource: primaryAudio, size: 36),
              ],
            ),
            const SizedBox(height: 8),
            // 假名和罗马音
            if (word.furigana != null && word.furigana!.isNotEmpty)
              Text(
                word.furigana!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            if (word.romaji != null && word.romaji!.isNotEmpty)
              Text(
                word.romaji!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 12),
            // 词性和音调
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (word.partOfSpeech != null)
                  _buildTag(context, word.partOfSpeech!, Colors.blue),
                if (word.jlptLevel != null)
                  _buildTag(
                    context,
                    word.jlptLevel!.toUpperCase(),
                    _getLevelColor(word.jlptLevel!),
                  ),
                if (word.pitchAccent != null)
                  _buildTag(context, '音调: ${word.pitchAccent}', Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // 释义列表
            ...meanings.map(
              (meaning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${meaning.definitionOrder}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meaning.meaningCn,
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (meaning.notes != null &&
                              meaning.notes!.isNotEmpty)
                            Text(
                              meaning.notes!,
                              style: theme.textTheme.bodySmall?.copyWith(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
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
