import 'package:breeze_jp/data/commands/active_user_command.dart';
import 'package:breeze_jp/data/commands/sync_remote_command.dart';
import 'package:breeze_jp/data/commands/sync_scheduler_command.dart';
import 'package:breeze_jp/data/models/user.dart';
import 'package:breeze_jp/data/queries/active_user_query.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveUserCommand extends Mock implements ActiveUserCommand {}

class _MockActiveUserQuery extends Mock implements ActiveUserQuery {}

class _MockSyncRemoteCommand extends Mock implements SyncRemoteCommand {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockActiveUserCommand activeUserCommand;
  late _MockActiveUserQuery activeUserQuery;
  late _MockSyncRemoteCommand syncRemoteCommand;

  final user = User(id: 1, username: 'u', passwordHash: 'p');

  setUp(() {
    activeUserCommand = _MockActiveUserCommand();
    activeUserQuery = _MockActiveUserQuery();
    syncRemoteCommand = _MockSyncRemoteCommand();

    when(() => activeUserQuery.getActiveUser()).thenAnswer((_) async => user);
    when(
      () => syncRemoteCommand.checkpointForCurrentUser(localUserId: 1),
    ).thenAnswer((_) async {});
  });

  test('syncs on app resume after threshold', () async {
    final command = SyncSchedulerCommand(
      activeUserCommand,
      activeUserQuery,
      syncRemoteCommand,
      periodicSyncInterval: const Duration(hours: 1),
      resumeSyncThreshold: const Duration(seconds: 30),
    );
    addTearDown(command.dispose);

    await command.start();
    command.debugSetLastSyncAt(
      DateTime.now().subtract(const Duration(seconds: 31)),
    );

    command.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => syncRemoteCommand.checkpointForCurrentUser(localUserId: 1),
    ).called(1);
  });
}
