import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'book_progress_repository.dart';

final bookProgressRepositoryProvider = Provider<BookProgressRepository>(
  (ref) => BookProgressRepository(() => AppDatabase.instance.database),
);
