import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'example_audio_repository.dart';

/// ExampleAudioRepository Provider
final exampleAudioRepositoryProvider = Provider<ExampleAudioRepository>((ref) {
  return ExampleAudioRepository();
});
