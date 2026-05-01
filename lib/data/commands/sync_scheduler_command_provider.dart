import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../queries/active_user_query_provider.dart';
import 'active_user_command_provider.dart';
import 'sync_remote_command.dart';
import 'sync_scheduler_command.dart';

final syncSchedulerCommandProvider = Provider<SyncSchedulerCommand>((ref) {
  final command = SyncSchedulerCommand(
    ref.read(activeUserCommandProvider),
    ref.read(activeUserQueryProvider),
    ref.read(syncRemoteCommandProvider),
  );
  ref.onDispose(command.dispose);
  return command;
});
