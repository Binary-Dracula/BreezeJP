import 'package:flutter/material.dart';
import '../../../data/models/grammar_detail.dart';
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
          _buildConnection(context),
          const SizedBox(height: 16),
          _buildMeaning(context),
          const SizedBox(height: 24),
          _buildExamples(context),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (grammar.jlptLevel != null)
                  _Tag(
                    label: grammar.jlptLevel!.toUpperCase(),
                    color: _jlptColor(grammar.jlptLevel!),
                  ),
                if (grammar.tags != null && grammar.tags!.isNotEmpty)
                  _Tag(label: grammar.tags!, color: Colors.grey.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnection(BuildContext context) {
    if (detail.grammar.connection == null ||
        detail.grammar.connection!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      title: '接续',
      content: Text(
        detail.grammar.connection!,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
      icon: Icons.link_rounded,
      color: Colors.orange,
    );
  }

  Widget _buildMeaning(BuildContext context) {
    if (detail.grammar.meaning == null || detail.grammar.meaning!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      title: '含义',
      content: Text(
        detail.grammar.meaning!,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
      icon: Icons.menu_book_rounded,
      color: Colors.blue,
    );
  }

  Widget _buildExamples(BuildContext context) {
    if (detail.examples.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            '例句',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...detail.examples.map(
          (example) => Card(
            margin: const EdgeInsets.only(bottom: 12),
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
        ),
      ],
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
