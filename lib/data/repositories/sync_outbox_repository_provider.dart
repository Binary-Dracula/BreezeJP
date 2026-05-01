import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'sync_outbox_repository.dart';

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>(
  (ref) => SyncOutboxRepository(() => AppDatabase.instance.database),
);
