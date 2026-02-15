import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'example_repository.dart';

/// ExampleRepository Provider
final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  return ExampleRepository(() => AppDatabase.instance.database);
});
