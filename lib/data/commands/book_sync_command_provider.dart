import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/preferences_provider.dart';
import '../queries/vocab_remote_query_provider.dart';
import '../repositories/book_repository_provider.dart';
import 'book_sync_command.dart';

final bookSyncCommandProvider = Provider<BookSyncCommand>((ref) {
  return BookSyncCommand(
    prefs: ref.read(sharedPreferencesProvider),
    remoteQuery: ref.read(vocabRemoteQueryProvider),
    bookRepository: ref.read(bookRepositoryProvider),
  );
});
