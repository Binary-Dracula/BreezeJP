import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'example_audio_repository.dart';

/// ExampleAudioRepository Provider
final exampleAudioRepositoryProvider = Provider<ExampleAudioRepository>((ref) {
  return ExampleAudioRepository(() => AppDatabase.instance.database);
});
