import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/utils/app_logger.dart';
import '../queries/active_user_query.dart';
import 'active_user_command.dart';
import 'sync_remote_command.dart';

class SyncSchedulerCommand with WidgetsBindingObserver {
  SyncSchedulerCommand(
    this._activeUserCommand,
    this._activeUserQuery,
    this._syncRemote, {
    Duration periodicSyncInterval = const Duration(seconds: 90),
    Duration resumeSyncThreshold = const Duration(seconds: 30),
  }) : _periodicSyncInterval = periodicSyncInterval,
       _resumeSyncThreshold = resumeSyncThreshold;

  final ActiveUserCommand _activeUserCommand;
  final ActiveUserQuery _activeUserQuery;
  final SyncRemoteCommand _syncRemote;
  final Duration _periodicSyncInterval;
  final Duration _resumeSyncThreshold;

  Timer? _periodicTimer;
  DateTime? _lastSyncAt;
  bool _started = false;
  bool _isSyncing = false;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    _lastSyncAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _periodicTimer = Timer.periodic(_periodicSyncInterval, (_) {
      unawaited(_syncCurrentUser(trigger: 'periodic'));
    });
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _lastSyncAt = null;

    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final lastSyncAt = _lastSyncAt;
    if (lastSyncAt == null ||
        DateTime.now().difference(lastSyncAt) >= _resumeSyncThreshold) {
      unawaited(_syncCurrentUser(trigger: 'resume'));
    }
  }

  @visibleForTesting
  Future<void> syncNowForTest() async {
    await _syncCurrentUser(trigger: 'test');
  }

  @visibleForTesting
  void debugSetLastSyncAt(DateTime? value) {
    _lastSyncAt = value;
  }

  Future<void> _syncCurrentUser({required String trigger}) async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      final activeUser =
          await _activeUserQuery.getActiveUser() ??
          await _activeUserCommand.ensureActiveUser();
      await _syncRemote.syncDownForCurrentUser(localUserId: activeUser.id);
      _lastSyncAt = DateTime.now();
      logger.info(
        '[SyncScheduler] completed trigger=$trigger userId=${activeUser.id}',
      );
    } catch (e, stackTrace) {
      logger.error('[SyncScheduler] failed trigger=$trigger', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    stop();
  }
}
