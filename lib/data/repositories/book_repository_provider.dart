import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(() => AppDatabase.instance.database);
});
