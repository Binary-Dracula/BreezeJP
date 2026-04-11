import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_service.dart';

/// 音频服务 Provider
/// 提供全局单例的音频播放服务
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
