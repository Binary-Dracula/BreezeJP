import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'word_audio_repository.dart';

/// WordAudioRepository Provider
final wordAudioRepositoryProvider = Provider<WordAudioRepository>((ref) {
  return WordAudioRepository(() => AppDatabase.instance.database);
});
