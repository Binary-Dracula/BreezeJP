import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/debug_state.dart';

final debugControllerProvider = NotifierProvider<DebugController, DebugState>(
  DebugController.new,
);

class DebugController extends Notifier<DebugState> {
  @override
  DebugState build() {
    return DebugState(testItems: _buildTestItems());
  }

  List<DebugTestItem> _buildTestItems() {
    return const [
      DebugTestItem(
        key: 'srs',
        title: 'SRS Algorithm Test',
        description: '测试 SM-2 / FSRS 算法行为与日志',
        route: '/debug/srs',
      ),
    ];
  }
}
