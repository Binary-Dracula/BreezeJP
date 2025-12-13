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
        key: 'kana_review_data',
        title: 'Kana Review Queue Generator',
        description: '生成假名待复习队列数据（驱动 Home/Review）',
        route: '/debug/kana-review-data',
      ),
      DebugTestItem(
        key: 'srs',
        title: 'SRS Algorithm Test',
        description: '测试 SM-2 / FSRS 算法行为与日志',
        route: '/debug/srs',
      ),
    ];
  }
}
