import 'package:flutter/material.dart';
import '../../../data/models/grammar_detail.dart';
import '../../../data/models/grammar_meaning.dart';
import '../../../data/models/grammar_example.dart';
import '../../learn/widgets/audio_play_button.dart';

class GrammarCard extends StatelessWidget {
  final GrammarDetail detail;

  const GrammarCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          ...detail.meanings.map(
            (meaning) => _buildMeaningSection(context, meaning),
          ),
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

  /// 渲染单个义项（接续 + 含义 + 例句 + 提示 + 提示例句）
  Widget _buildMeaningSection(BuildContext context, GrammarMeaning meaning) {
    // 分离义项例句和提示例句
    final regularExamples = meaning.examples
        .where((e) => !e.isTipExample)
        .toList();
    final tipExamples = meaning.examples.where((e) => e.isTipExample).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 接续
          if (meaning.connection != null && meaning.connection!.isNotEmpty)
            _SectionCard(
              title: '接续',
              content: Text(
                meaning.connection!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              icon: Icons.link_rounded,
              color: Colors.orange,
            ),
          if (meaning.connection != null && meaning.connection!.isNotEmpty)
            const SizedBox(height: 12),

          // 含义
          if (meaning.meaning != null && meaning.meaning!.isNotEmpty)
            _SectionCard(
              title: '含义',
              content: Text(
                meaning.meaning!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              icon: Icons.menu_book_rounded,
              color: Colors.blue,
            ),
          if (meaning.meaning != null && meaning.meaning!.isNotEmpty)
            const SizedBox(height: 12),

          // 义项例句
          if (regularExamples.isNotEmpty)
            _buildExampleList(context, regularExamples),

          // 提示
          if (meaning.tip != null && meaning.tip!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: '提示',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meaning.tip!,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  // 提示中的例句
                  if (tipExamples.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildExampleList(context, tipExamples),
                  ],
                ],
              ),
              icon: Icons.tips_and_updates_rounded,
              color: Colors.amber.shade700,
            ),
          ],

          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildExampleList(
    BuildContext context,
    List<GrammarExample> examples,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: examples
          .map(
            (example) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            example.sentence ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          ),
                        ),
                        if (example.audioUrl != null &&
                            example.audioUrl!.isNotEmpty)
                          AudioPlayButton(
                            audioSource: example.audioUrl!,
                            size: 24,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    if (example.translation != null) ...[
                      const Divider(height: 24),
                      Text(
                        example.translation!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
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
