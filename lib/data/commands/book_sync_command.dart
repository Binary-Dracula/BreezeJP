import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../queries/vocab_remote_query.dart';
import '../repositories/book_repository.dart';

class BookSyncCommand {
  BookSyncCommand({
    required SharedPreferences prefs,
    required VocabRemoteQuery remoteQuery,
    required BookRepository bookRepository,
  }) : _prefs = prefs,
       _remoteQuery = remoteQuery,
       _bookRepository = bookRepository;

  final SharedPreferences _prefs;
  final VocabRemoteQuery _remoteQuery;
  final BookRepository _bookRepository;

  static const _lastSyncKey = 'books_last_sync_time';
  static const _selectedBookKey = 'selected_book_id';

  Future<int> syncBooks() async {
    final lastSync = _prefs.getString(_lastSyncKey);

    if (lastSync == null) {
      final response = await _remoteQuery.fetchBooks();
      await _bookRepository.upsertBooks(response.books);
      await _prefs.setString(_lastSyncKey, response.serverTime);
      await _clearUnavailableSelectedBook();
      logger.info('[BookSync] 首次同步完成，count=${response.books.length}');
      return response.books.length;
    }

    final response = await _remoteQuery.fetchBookSync(since: lastSync);
    if (response.books.isNotEmpty) {
      await _bookRepository.upsertBooks(response.books);
    }
    await _prefs.setString(_lastSyncKey, response.serverTime);
    await _clearUnavailableSelectedBook();
    logger.info('[BookSync] 增量同步完成，count=${response.books.length}');
    return response.books.length;
  }

  Future<void> _clearUnavailableSelectedBook() async {
    final selectedBookId = _prefs.getString(_selectedBookKey);
    if (selectedBookId == null) return;

    final book = await _bookRepository.getBookById(selectedBookId);
    if (book == null || !book.isAvailable) {
      await _prefs.remove(_selectedBookKey);
      logger.info('[BookSync] 当前选中辞书已失效，已清空 selected_book_id');
    }
  }
}
