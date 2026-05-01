import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'sync_state_repository.dart';

final syncStateRepositoryProvider = Provider<SyncStateRepository>(
  (ref) => SyncStateRepository(() => AppDatabase.instance.database),
);
