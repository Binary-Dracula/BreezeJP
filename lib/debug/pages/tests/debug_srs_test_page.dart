import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/kana/review/controller/matching_controller.dart';

class DebugSrsTestPage extends ConsumerWidget {
  const DebugSrsTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('SRS Debug')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final controller = ref.read(matchingControllerProvider.notifier);
            final result = await controller.simulateReviewSequence(1, 1, const [
              2,
              2,
              2,
              3,
              1,
              2,
              3,
            ]);

            logger.debug('SRS Simulation finalState: ${result['finalState']}');
            logger.debug('SRS Simulation logs: ${result['logs']}');

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Simulation Completed')),
              );
            }
          },
          child: const Text('Run SRS Simulation'),
        ),
      ),
    );
  }
}
