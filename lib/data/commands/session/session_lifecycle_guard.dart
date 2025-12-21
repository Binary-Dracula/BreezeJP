/// SessionLifecycleGuard exists to guarantee exactly-once side effects
/// without leaking lifecycle responsibility into feature controllers.
enum SessionLifecycleState {
  open,
  flushing,
  flushed,
}

class SessionLifecycleGuard {
  SessionLifecycleState _state = SessionLifecycleState.open;

  bool get isFlushed => _state == SessionLifecycleState.flushed;

  /// 执行 flush（只允许一次）
  Future<void> flushOnce(Future<void> Function() action) async {
    if (_state != SessionLifecycleState.open) return;

    _state = SessionLifecycleState.flushing;
    try {
      await action();
    } finally {
      _state = SessionLifecycleState.flushed;
    }
  }
}
