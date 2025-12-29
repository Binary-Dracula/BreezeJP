import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/commands/daily_stat_command.dart';

/// 页面驻留计时器（工程封板）
///
/// 规则：
/// - 学习时长的【唯一来源】
/// - 只负责统计页面处于前台可见的时间
/// - 只写入 daily_stats.total_time_ms
///
/// 禁止：
/// - 行为日志携带 duration
/// - 从 logs / session 推导学习时长
/// - 页面直接写 daily_stats
///
/// ⚠️ 此类为统计底座，不得复制或绕过
class PageDurationTracker with WidgetsBindingObserver {
  PageDurationTracker(this.ref);

  final WidgetRef ref;

  static const int _minDurationMs = 2000;

  int? _enterTimestampMs;
  bool _isTracking = false;

  /// 页面进入时调用
  void onEnter() {
    if (_isTracking) return;
    _isTracking = true;
    _enterTimestampMs = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addObserver(this);
  }

  /// 页面退出时调用
  Future<void> onExit() async {
    if (!_isTracking) return;
    await _flush();
    WidgetsBinding.instance.removeObserver(this);
    _isTracking = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _flush();
      return;
    }

    if (state == AppLifecycleState.resumed && _enterTimestampMs == null) {
      _enterTimestampMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _flush() async {
    final enterTs = _enterTimestampMs;
    if (enterTs == null) return;

    _enterTimestampMs = null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = now - enterTs;
    if (durationMs < _minDurationMs) return;

    await ref
        .read(dailyStatCommandProvider)
        .applyTimeOnlyDelta(durationMs: durationMs);
  }
}
