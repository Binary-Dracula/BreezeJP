import 'package:flutter/material.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';

import '../../../core/widgets/custom_ruby_text.dart';
import '../../../data/models/word_detail.dart';

class WordInsightsSection extends StatelessWidget {
  final WordRichContent richContent;

  const WordInsightsSection({super.key, required this.richContent});

  @override
  Widget build(BuildContext context) {
    final hasInsights =
        richContent.grammarRuleEntries.isNotEmpty ||
        richContent.collocationEntries.isNotEmpty ||
        richContent.synonymEntries.isNotEmpty ||
        richContent.antonymEntries.isNotEmpty ||
        richContent.commonMistakeEntries.isNotEmpty;
    if (!hasInsights) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.wordAdditionalInfo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (richContent.grammarRuleEntries.isNotEmpty) ...[
              _InsightGroupTitle(title: l10n.wordGrammarHints),
              const SizedBox(height: 8),
              ...richContent.grammarRuleEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PatternItem(
                    title: entry.pattern,
                    description: entry.explanation,
                  ),
                ),
              ),
            ],
            if (richContent.collocationEntries.isNotEmpty) ...[
              _sectionGap(),
              _InsightGroupTitle(title: l10n.wordCollocations),
              const SizedBox(height: 8),
              ...richContent.collocationEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PatternItem(
                    title: entry.phrase,
                    description: entry.meaning,
                  ),
                ),
              ),
            ],
            if (richContent.synonymEntries.isNotEmpty) ...[
              _sectionGap(),
              _InsightGroupTitle(title: l10n.wordSimilarWords),
              const SizedBox(height: 8),
              _RelationWrap(entries: richContent.synonymEntries),
            ],
            if (richContent.antonymEntries.isNotEmpty) ...[
              _sectionGap(),
              _InsightGroupTitle(title: l10n.wordOppositeWords),
              const SizedBox(height: 8),
              _RelationWrap(entries: richContent.antonymEntries),
            ],
            if (richContent.commonMistakeEntries.isNotEmpty) ...[
              _sectionGap(),
              _InsightGroupTitle(title: l10n.wordCommonMistakes),
              const SizedBox(height: 8),
              ...richContent.commonMistakeEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MistakeItem(entry: entry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionGap() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1),
  );
}

class _InsightGroupTitle extends StatelessWidget {
  final String title;

  const _InsightGroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: const Color(0xFF1E293B),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PatternItem extends StatelessWidget {
  final String title;
  final String description;

  const _PatternItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JapaneseSentence(
            text: title,
            fontSize: 16,
            rubyFontSize: 10,
            textColor: const Color(0xFF1E293B),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationWrap extends StatelessWidget {
  final List<WordRelationEntry> entries;

  const _RelationWrap({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _RelationCard(entry: entries[index]),
          if (index != entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RelationCard extends StatelessWidget {
  final WordRelationEntry entry;

  const _RelationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JapaneseSentence(
            text: entry.word,
            fontSize: 16,
            rubyFontSize: 10,
            textColor: const Color(0xFF1E293B),
          ),
          if (entry.meaning?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.meaning!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          if (entry.difference?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                entry.difference!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MistakeItem extends StatelessWidget {
  final WordCommonMistakeEntry entry;

  const _MistakeItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.mistakeType?.isNotEmpty == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.mistakeType!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (entry.mistakeType?.isNotEmpty == true) const SizedBox(height: 8),
          Text(
            entry.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7C2D12),
            ),
          ),
        ],
      ),
    );
  }
}
