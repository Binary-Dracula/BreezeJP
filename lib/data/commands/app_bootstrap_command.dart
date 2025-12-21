import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'active_user_command_provider.dart';

enum AppBootstrapStatus {
  ready,
}

class AppBootstrapResult {
  final AppBootstrapStatus status;
  const AppBootstrapResult(this.status);
}

class AppBootstrapCommand {
  AppBootstrapCommand(this._ref);

  final Ref _ref;

  Future<AppBootstrapResult> run() async {
    final activeUserCommand = _ref.read(activeUserCommandProvider);
    await activeUserCommand.ensureActiveUser();

    // Ensure database is initialized and available to data layer.
    _ref.read(databaseProvider);

    return const AppBootstrapResult(AppBootstrapStatus.ready);
  }
}
