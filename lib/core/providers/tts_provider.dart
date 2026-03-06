import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/tts_service.dart';
import '../../services/voicevox_tts_service.dart';

/// TTS 服务 Provider
/// 使用 Provider 而非 Notifier，因为服务生命周期通常伴随应用整个生命周期
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = VoicevoxTtsService();

  // 在 Provider 销毁时自动释放引擎资源
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// TTS 初始化状态 Provider
/// 用于 UI 层监听初始化进度或状态
final ttsInitializedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  if (!service.isInitialized) {
    await service.initialize();
  }
  return service.isInitialized;
});
