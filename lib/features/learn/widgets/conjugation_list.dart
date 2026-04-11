import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

/// 活用变形列表（2.0 — 从 WordRichContent.conjugations Map 渲染）
class ConjugationList extends StatelessWidget {
  final Map<String, dynamic>? conjugations;

  const ConjugationList({super.key, required this.conjugations});

  @override
  Widget build(BuildContext context) {
    if (conjugations == null || conjugations!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final borderColor = theme.dividerColor;
    final l10n = AppLocalizations.of(context)!;

    // conjugations 是一个 Map，key 是变形类型名(如"ます形")，value 是变形后的词
    final entries = conjugations!.entries.toList();

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
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 0.5),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: borderColor.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final typeName = entry.key;
              final value = entry.value?.toString() ?? '';
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
                        typeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        value,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
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
}
