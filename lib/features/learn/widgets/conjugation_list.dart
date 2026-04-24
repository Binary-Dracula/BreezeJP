import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../../../core/widgets/custom_ruby_text.dart';
import '../../../data/models/word_detail.dart';

/// 活用变形列表（2.0 — 从归一化后的 WordRichContent.conjugationEntries 渲染）
class ConjugationList extends StatelessWidget {
  final Map<String, dynamic>? conjugations;

  const ConjugationList({super.key, required this.conjugations});

  @override
  Widget build(BuildContext context) {
    if (conjugations == null || conjugations!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entries = WordRichContent(
      meanings: const [],
      conjugations: conjugations,
    ).conjugationEntries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            l10n.conjugationTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _labelForKey(entry.key, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: JapaneseSentence(
                        text: entry.value,
                        fontSize: theme.textTheme.bodyLarge?.fontSize ?? 16,
                        rubyFontSize: 10,
                        textColor: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _labelForKey(String key, AppLocalizations l10n) {
    switch (key) {
      case 'dictionary_form':
        return l10n.conjugationDictionaryForm;
      case 'masu_form':
        return l10n.conjugationMasuForm;
      case 'te_form':
        return l10n.conjugationTeForm;
      case 'ta_form':
        return l10n.conjugationTaForm;
      case 'nai_form':
        return l10n.conjugationNaiForm;
      case 'potential_form':
        return l10n.conjugationPotentialForm;
      case 'passive_form':
        return l10n.conjugationPassiveForm;
      case 'causative_form':
        return l10n.conjugationCausativeForm;
      default:
        return key.replaceAll('_', ' ');
    }
  }
}
