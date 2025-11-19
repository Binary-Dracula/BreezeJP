import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_service.dart';

/// 音频服务 Provider
/// 提供全局单例的音频播放服务
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();

  // 当 Provider 被销毁时，释放音频资源
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
