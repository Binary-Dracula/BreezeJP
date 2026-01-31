import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/commands/debug_seed_command.dart';
import '../../data/commands/debug_seed_command_provider.dart';

class DebugPlaceholderPage extends ConsumerStatefulWidget {
  const DebugPlaceholderPage({super.key});

  @override
  ConsumerState<DebugPlaceholderPage> createState() =>
      _DebugPlaceholderPageState();
}

class _DebugPlaceholderPageState extends ConsumerState<DebugPlaceholderPage> {
  bool _isSeeding = false;
  DebugSeedResult? _lastResult;
  String? _error;

  Future<void> _seedReviewData() async {
    if (_isSeeding) return;
    setState(() {
      _isSeeding = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(debugSeedCommandProvider)
          .seedLearningData(perType: 10);

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _isSeeding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.summary())),
      );
    } catch (e, stackTrace) {
      logger.error('Seed review data failed', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSeeding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick seed for word/kana reviews (10 each)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSeeding ? null : _seedReviewData,
                icon: _isSeeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isSeeding ? 'Seeding...' : 'Seed Review Data'),
              ),
            ),
            const SizedBox(height: 12),
            if (_lastResult != null)
              Text(
                _lastResult!.summary(),
                style: const TextStyle(color: Colors.green),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
