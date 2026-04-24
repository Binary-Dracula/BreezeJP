import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../../../data/models/word_detail.dart';
import '../../../core/widgets/custom_ruby_text.dart';
import 'audio_play_button.dart';

/// 单词头部信息（2.0 — 对齐新 Word 模型）
class WordHeader extends StatelessWidget {
  final WordDetail wordDetail;

  const WordHeader({super.key, required this.wordDetail});

  @override
  Widget build(BuildContext context) {
    final word = wordDetail.word;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JapaneseSentence(
                  text: word.word,
                  fontSize: 32,
                  rubyFontSize: 12,
                  textColor: const Color(0xFF1E293B),
                ),
                if (word.reading.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      word.reading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5C8DFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (word.romaji?.isNotEmpty == true)
                  Text(
                    word.romaji!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                if (word.audioSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C8DFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: AudioPlayButton(
                          audioSource: word.audioSource,
                          size: 28,
                          color: const Color(0xFF5C8DFF),
                        ),
                      ),
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
                    color: const Color(0xFF14B8A6),
                  ),
                if (word.pitchAccent?.isNotEmpty == true)
                  _Tag(
                    label: l10n.wordPitchAccentLabel(word.pitchAccent!),
                    color: const Color(0xFF0EA5E9),
                  ),
                if (word.jlptLevel?.isNotEmpty == true)
                  _Tag(
                    label: word.jlptLevel!.toUpperCase(),
                    color: _jlptColor(word.jlptLevel!),
                  ),
                if (word.transitivity?.isNotEmpty == true)
                  _Tag(label: word.transitivity!, color: Colors.indigo),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
