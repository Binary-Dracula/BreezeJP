import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/debug/tools/debug_kana_review_data_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugKanaReviewDataGeneratorPage extends ConsumerStatefulWidget {
  const DebugKanaReviewDataGeneratorPage({super.key});

  @override
  ConsumerState<DebugKanaReviewDataGeneratorPage> createState() =>
      _DebugKanaReviewDataGeneratorPageState();
}

class _DebugKanaReviewDataGeneratorPageState
    extends ConsumerState<DebugKanaReviewDataGeneratorPage> {
  bool _isGenerating = false;
  bool _clearExistingForUser = false;

  Future<void> _generate() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      await DebugKanaReviewDataGenerator.generateMockKanaReviewQueueData(
        clearExistingForUser: _clearExistingForUser,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock kana review data generated')),
      );
    } catch (e, stackTrace) {
      logger.error(
        'Debug mock kana review data generation failed',
        e,
        stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Generate failed: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kana Review Data Generator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Clear existing kana review data for user'),
              value: _clearExistingForUser,
              onChanged: _isGenerating
                  ? null
                  : (value) => setState(() => _clearExistingForUser = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                child: Text(_isGenerating ? 'Generating...' : 'Generate'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'After generating, go back to Home to see kana review count, '
              'then enter Matching review to start.',
            ),
          ],
        ),
      ),
    );
  }
}
