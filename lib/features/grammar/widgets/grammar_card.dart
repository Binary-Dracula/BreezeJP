import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/grammar_detail.dart';
import '../../../data/models/grammar_meaning.dart';
import '../../../data/models/grammar_context.dart';
import '../../../data/models/grammar_example.dart';
import '../../../core/widgets/common_example_item.dart';

class GrammarCard extends ConsumerWidget {
  final GrammarDetail detail;

  const GrammarCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          // 渲染义项与接续
          ...detail.meanings.map(
            (meaning) => _buildMeaningSection(context, ref, meaning),
          ),
          // 渲染场景与限制条件
          ...detail.contexts.map(
            (contextData) => _buildContextSection(context, ref, contextData),
          ),
          // 渲染例句列表
          if (detail.examples.isNotEmpty)
            _buildExampleList(context, ref, detail.examples),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final grammar = detail.grammar;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              grammar.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (grammar.jlptLevel != null)
              _Tag(
                label: grammar.jlptLevel!.toUpperCase(),
                color: _jlptColor(grammar.jlptLevel!),
              ),
          ],
        ),
      ),
    );
  }

  /// 渲染单个义项（含义 + 接续）
  Widget _buildMeaningSection(
    BuildContext context,
    WidgetRef ref,
    GrammarMeaning meaning,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 含义 (只展示中文)
          if (meaning.definitionCn != null && meaning.definitionCn!.isNotEmpty)
            _SectionCard(
              title: '含义',
              content: Text(
                meaning.definitionCn!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              icon: Icons.menu_book_rounded,
              color: Colors.blue,
            ),
          if (meaning.definitionCn != null && meaning.definitionCn!.isNotEmpty)
            const SizedBox(height: 12),

          // 接续 (只展示中文)
          if (meaning.howToUseCn != null && meaning.howToUseCn!.isNotEmpty)
            _SectionCard(
              title: '接续',
              content: Text(
                meaning.howToUseCn!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              icon: Icons.link_rounded,
              color: Colors.orange,
            ),
          if (meaning.howToUseCn != null && meaning.howToUseCn!.isNotEmpty)
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 渲染场景提示与限制
  Widget _buildContextSection(
    BuildContext context,
    WidgetRef ref,
    GrammarContext contextData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 提示 (只展示中文)
          if (contextData.whenToUseCn != null &&
              contextData.whenToUseCn!.isNotEmpty)
            _SectionCard(
              title: '提示',
              content: Text(
                contextData.whenToUseCn!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              icon: Icons.tips_and_updates_rounded,
              color: Colors.amber.shade700,
            ),
          if (contextData.whenToUseCn != null &&
              contextData.whenToUseCn!.isNotEmpty)
            const SizedBox(height: 12),

          // 限制条件数组 (只展示中文)
          if (contextData.limitations.isNotEmpty) ...[
            _SectionCard(
              title: '格式与限制',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contextData.limitations
                    .map(
                      (limit) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '•',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                limit,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              icon: Icons.rule_rounded,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildExampleList(
    BuildContext context,
    WidgetRef ref,
    List<GrammarExample> examples,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_quote_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  '例句',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(examples.length, (index) {
              final example = examples[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == examples.length - 1 ? 0 : 20,
                ),
                child: CommonExampleItem(
                  order: index + 1,
                  primaryColor: primaryColor,
                  data: ExampleDisplayData(
                    japanese: example.sentence ?? '',
                    translation: example.translationCn,
                    audioSource: example.audioUrl,
                    ttsText: example.sentence,
                  ),
                ),
              );
            }),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData icon;
  final Color color;

  const _SectionCard({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
