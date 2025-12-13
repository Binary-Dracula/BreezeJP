import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/debug_controller.dart';
import '../widgets/debug_test_tile.dart';

class DebugPage extends ConsumerWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(debugControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Tools')),
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
