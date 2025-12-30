import 'package:flutter/widgets.dart';

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
  PageDurationTracker(this._dailyStatCommand);

  final DailyStatCommand _dailyStatCommand;

  static const int _minDurationMs = 2000;

  int? _enterTimestampMs;
  DateTime? _enterDate;
  bool _isTracking = false;

  /// 页面进入时调用
  void onEnter() {
    if (_isTracking) return;
    _isTracking = true;
    final now = DateTime.now();
    _enterTimestampMs = now.millisecondsSinceEpoch;
    _enterDate = DateTime(now.year, now.month, now.day);
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
      final now = DateTime.now();
      _enterTimestampMs = now.millisecondsSinceEpoch;
      _enterDate = DateTime(now.year, now.month, now.day);
    }
  }

  Future<void> _flush() async {
    final enterTs = _enterTimestampMs;
    final date = _enterDate;
    if (enterTs == null || date == null) return;

    _enterTimestampMs = null;
    _enterDate = null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = now - enterTs;
    if (durationMs < _minDurationMs) return;

    await _dailyStatCommand.applyTimeOnlyDelta(
      durationMs: durationMs,
      date: date,
    );
  }
}
