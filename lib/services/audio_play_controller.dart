import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../core/utils/app_logger.dart';
import 'audio_play_state.dart';
import 'audio_service_provider.dart';

/// 音频播放控制器（状态机实现）
/// 管理音频播放状态，支持多个音频按钮同步显示状态
class AudioPlayController extends Notifier<AudioPlayStatus> {
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  AudioPlayStatus build() {
    _setupPlayerStateListener();
    return const AudioPlayStatus();
  }

  /// 监听 AudioPlayer 状态变化
  void _setupPlayerStateListener() {
    final audioService = ref.read(audioServiceProvider);

    _playerStateSubscription = audioService.player.playerStateStream.listen((
      playerState,
    ) {
      if (playerState.processingState == ProcessingState.completed) {
        // 播放完成 → 回到 idle，保留 currentSource，避免与新 loading 竞态
        if (state.state != AudioPlayState.loading) {
          state = AudioPlayStatus(
            state: AudioPlayState.idle,
            currentSource: state.currentSource,
          );
        }
        logger.debug('音频播放完成，状态回到 idle');
      } else if (playerState.playing) {
        // 正在播放
        final resolvedSource = state.currentSource?.isNotEmpty == true
            ? state.currentSource
            : (audioService.currentAudioSource.isNotEmpty
                  ? audioService.currentAudioSource
                  : null);

        if (state.state != AudioPlayState.playing ||
            state.currentSource != resolvedSource) {
          state = AudioPlayStatus(
            state: AudioPlayState.playing,
            currentSource: resolvedSource,
          );
        }
      }
    });

    // 清理订阅
    ref.onDispose(() {
      _playerStateSubscription?.cancel();
    });
  }

  /// 播放音频
  Future<void> play(String source) async {
    final audioService = ref.read(audioServiceProvider);

    // idle/playing → loading
    state = AudioPlayStatus(
      state: AudioPlayState.loading,
      currentSource: source,
    );

    try {
      await audioService.playAudio(source);
      // loading → playing (由 listener 处理)
    } catch (e) {
      // loading → error
      state = AudioPlayStatus(
        state: AudioPlayState.error,
        currentSource: source,
        errorMessage: e.toString(),
      );
      logger.error('音频播放失败: $source', e);
    }
  }

  /// 停止音频
  Future<void> stop() async {
    final audioService = ref.read(audioServiceProvider);

    try {
      await audioService.stop();
      // playing → idle
      state = const AudioPlayStatus(state: AudioPlayState.idle);
    } catch (e) {
      logger.error('音频停止失败', e);
    }
  }

  /// 切换播放/停止
  Future<void> toggle(String source) async {
    if (state.isPlaying(source)) {
      await stop();
    } else {
      // 如果正在播放其他音频，先停止
      if (state.state == AudioPlayState.playing) {
        await stop();
      }
      await play(source);
    }
  }

  /// 使用 TTS 朗读文本
  ///
  /// 使用 `tts://{text}` 格式作为虚拟音频源标识,
  /// 以便复用现有的状态机追踪哪个 TTS 正在播放。
  ///
  /// 状态流转: loading (合成中) → playing (listener 检测) → idle (listener 检测)
  Future<void> speakTts(String text) async {
    final audioService = ref.read(audioServiceProvider);
    final ttsSource = 'tts://$text';

    // idle → loading (显示加载中旋转图标)
    state = AudioPlayStatus(
      state: AudioPlayState.loading,
      currentSource: ttsSource,
    );

    try {
      await audioService.speakText(text);
      // loading → playing → idle 由 _setupPlayerStateListener 自动处理
    } catch (e) {
      state = AudioPlayStatus(
        state: AudioPlayState.error,
        currentSource: ttsSource,
        errorMessage: e.toString(),
      );
      logger.error('TTS 朗读失败: $text', e);
    }
  }

  /// 切换 TTS 播放/停止
  Future<void> toggleTts(String text) async {
    final ttsSource = 'tts://$text';

    if (state.isPlaying(ttsSource)) {
      await stop();
    } else {
      // 停止上一个音频/TTS
      if (state.state == AudioPlayState.playing ||
          state.state == AudioPlayState.loading) {
        await stop();
      }
      await speakTts(text);
    }
  }

  /// 重置状态（用于错误恢复）
  void reset() {
    state = const AudioPlayStatus(state: AudioPlayState.idle);
  }
}
