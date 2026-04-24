import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../db/app_database.dart';
import 'book_sync_command_provider.dart';
import 'active_user_command_provider.dart';
import 'word_sync_command_provider.dart';

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

    try {
      await _ref.read(bookSyncCommandProvider).syncBooks();
    } catch (e) {
      logger.error('[Bootstrap] Book sync failed, skipping', e);
    }

    try {
      await _ref.read(wordSyncCommandProvider).syncUpdatedWords();
    } catch (e) {
      logger.error('[Bootstrap] Word sync failed, skipping', e);
    }

    return const AppBootstrapResult(AppBootstrapStatus.ready);
  }
}
