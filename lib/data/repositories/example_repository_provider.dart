import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'example_repository.dart';

/// ExampleRepository Provider
final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  return ExampleRepository();
});
