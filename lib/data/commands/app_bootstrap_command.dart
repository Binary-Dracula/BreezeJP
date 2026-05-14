import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import 'active_user_command_provider.dart';

enum AppBootstrapStatus { ready }

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
    await AppDatabase.instance.database;

    logger.info('[Bootstrap] 本地用户与数据库初始化完成，页面按需加载远端数据');

    return const AppBootstrapResult(AppBootstrapStatus.ready);
  }
}
