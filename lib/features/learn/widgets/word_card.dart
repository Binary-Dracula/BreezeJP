import 'package:flutter/material.dart';
import '../../../data/models/word_detail.dart';

/// 单词卡片组件 - 显示单词的核心信息
class WordCard extends StatelessWidget {
  final WordDetail wordDetail;
  final bool isPlayingAudio;
  final VoidCallback onPlayAudio;

  const WordCard({
    super.key,
    required this.wordDetail,
    required this.isPlayingAudio,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = wordDetail.word;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 单词文本
            Text(
              word.word,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),

            // 假名
            if (word.furigana != null)
              Text(
                word.furigana!,
                style: TextStyle(
                  fontSize: 20,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),

            // 罗马音
            if (word.romaji != null) ...[
              const SizedBox(height: 4),
              Text(
                word.romaji!,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 音频播放按钮
            if (wordDetail.primaryAudioPath != null)
              IconButton.filled(
                onPressed: onPlayAudio,
                icon: Icon(isPlayingAudio ? Icons.stop : Icons.volume_up),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // 词性和 JLPT 等级
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.partOfSpeech != null) ...[
                  Chip(
                    label: Text(word.partOfSpeech!),
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (word.jlptLevel != null)
                  Chip(
                    label: Text(word.jlptLevel!),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 释义
            ...wordDetail.meanings.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.meaningCn,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
