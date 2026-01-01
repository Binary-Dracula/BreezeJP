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
        key: 'statistics',
        title: 'Statistics Debug',
        description: '只读统计验证页（daily_stats / mastered / streak）',
        route: '/debug/statistics',
      ),
      DebugTestItem(
        key: 'first_learn',
        title: 'FirstLearn Inspector',
        description: 'firstLearn 最近日志（需传 userId 参数）',
        route: '/debug/first-learn',
      ),
      DebugTestItem(
        key: 'study_words',
        title: 'StudyWords Inspector',
        description: 'study_words 状态快照（需传 userId 参数）',
        route: '/debug/study-words',
      ),
      DebugTestItem(
        key: 'study_logs',
        title: 'StudyLogs Inspector',
        description: 'study_logs 行为日志（需传 userId 参数）',
        route: '/debug/study-logs',
      ),
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
