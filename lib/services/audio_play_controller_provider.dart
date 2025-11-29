import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_play_controller.dart';
import 'audio_play_state.dart';

/// 音频播放控制器 Provider
/// 提供全局的音频播放状态管理
final audioPlayControllerProvider =
    NotifierProvider<AudioPlayController, AudioPlayStatus>(
      AudioPlayController.new,
    );
