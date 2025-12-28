import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/commands/daily_stat_command.dart';

/// 页面驻留计时器（仅负责时长累计）
class PageDurationTracker {
  PageDurationTracker(this.ref);

  final Ref ref;

  int? _enterTimestampMs;

  /// 页面进入时调用
  void onEnter() {
    _enterTimestampMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// 页面退出时调用
  Future<void> onExit() async {
    final enterTs = _enterTimestampMs;
    if (enterTs == null) return;

    _enterTimestampMs = null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = now - enterTs;
    if (durationMs <= 0) return;

    await ref.read(dailyStatCommandProvider).applyTimeOnlyDelta(
          durationMs: durationMs,
        );
  }
}
