import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../commands/debug_reset_learning_command_provider.dart';
import '../controller/debug_controller.dart';
import '../widgets/debug_test_tile.dart';

class DebugPage extends ConsumerStatefulWidget {
  const DebugPage({super.key});

  @override
  ConsumerState<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends ConsumerState<DebugPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debugControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        actions: kDebugMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'Reset Learning Data',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Reset learning data?'),
                        content: const Text(
                          'This will delete study_words, study_logs, kana_logs, '
                          'kana_learning_state for the current user.\n\n'
                          'This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    try {
                      await ref
                          .read(debugResetLearningCommandProvider)
                          .resetLearningData();
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reset failed: $error')),
                      );
                      return;
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Learning data cleared')),
                    );
                    setState(() {});
                  },
                ),
              ]
            : null,
      ),
      body: ListView.builder(
        itemCount: state.testItems.length,
        itemBuilder: (context, index) {
          final item = state.testItems[index];
          return DebugTestTile(item: item);
        },
      ),
    );
  }
}
