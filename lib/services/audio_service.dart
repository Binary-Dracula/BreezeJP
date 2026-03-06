import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import '../core/utils/app_logger.dart';
import 'tts_service.dart';

/// 音频播放服务
/// 负责处理单词和例句的音频播放
/// 支持本地资源文件和在线 URL 音频
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final TtsService? _ttsService;

  AudioService({TtsService? ttsService}) : _ttsService = ttsService;

  /// 获取播放器实例
  AudioPlayer get player => _player;

  /// 当前播放器的状态
  AudioStateEnum _currentState = AudioStateEnum.unplayed;

  /// 当前播放的音频来源
  String _currentAudioSource = '';

  /// 获取当前播放状态
  AudioStateEnum get currentState => _currentState;

  /// 获取当前音频源
  String get currentAudioSource => _currentAudioSource;

  /// 播放音频
  Future<void> playAudio(String? source) async {
    if (source == null || source.isEmpty) {
      logger.warning('音频源为空，尝试调用 TTS 朗读');
      // 这里如果知道文本内容就好了。
      // TODO: 考虑修改 playAudio 接口支持传文本，或者从 source 以外的地方获取文本。
      // 为了最小改动，我们假设逻辑上 source 为空时，如果有 fallbackText 则朗读。
      return;
    }

    try {
      // 如果是同一个音频源，重新播放
      if (_currentAudioSource == source) {
        await _player.seek(Duration.zero);
        await _player.play();
        _currentState = AudioStateEnum.playing;
        logger.audioStateChange(newState: _currentState.name);
        return;
      }

      // 不同音频源，先停止再加载
      if (_player.playing) {
        await _player.stop();
        _currentState = AudioStateEnum.unplayed;
      }

      _currentAudioSource = source;

      // 判断是 URL 还是本地资源
      if (source.startsWith('http://') || source.startsWith('https://')) {
        // 在线音频：对 URL 进行 percent-encoding 以兼容 Android ExoPlayer
        // Android 的 OkHttp 不会自动编码非 ASCII 字符（如日文汉字），导致 404
        final encodedUrl = _encodeUrl(source);
        await _player.setUrl(
          encodedUrl,
          headers: {'X-Breeze-Token': 'BreezeJP-2026-Secret-V1'},
        );
      } else {
        // 本地资源
        await _player.setAsset(source);
      }

      // 开始播放
      await _player.play();
      _currentState = AudioStateEnum.playing;
      logger.audioStateChange(newState: _currentState.name);
    } catch (e) {
      logger.warning('播放音频失败，尝试使用 TTS 作为 Fallback: $source, 错误: $e');

      // Fallback 到 TTS
      // 注意：这里需要知道文本内容。通常 source 可能就是路径，
      // 如果要 TTS，我们需要原始文本。
      // 我们暂且在 playAudio 增加一个可选参数 text。
      _currentState = AudioStateEnum.unplayed;
      rethrow;
    }
  }

  /// 朗读纯文本 (通过 TTS 合成 + 本地播放器)
  ///
  /// TTS 合成返回 WAV 字节后, 使用 AudioService 自身的 _player 播放,
  /// 这样 AudioPlayController 的 playerStateStream 监听器能正确捕获
  /// playing / completed 状态变化, 实现按钮状态正常轮转。
  Future<void> speakText(String text) async {
    if (_ttsService == null) {
      logger.error('TTS 服务未初始化，无法朗读文本');
      return;
    }

    try {
      // 如果正在播放音频，先停止
      if (_player.playing) {
        await _player.stop();
      }

      // 合成 WAV 音频数据
      final wavBytes = await _ttsService.synthesize(text);

      // 使用 AudioService 自身的 _player 播放
      // (AudioPlayController 监听的就是这个 player)
      await _player.setAudioSource(_WavAudioSource(wavBytes));
      await _player.setSpeed(_ttsService.speed);
      await _player.play();

      _currentState = AudioStateEnum.playing;
      _currentAudioSource = 'tts://$text';
    } catch (e) {
      logger.error('TTS 朗读失败: $text', e);
      rethrow;
    }
  }

  /// 播放音频，失败时自动 TTS 朗读 fallbackText
  ///
  /// 优先尝试播放 [source] 指向的音频文件,
  /// 如果 source 为空或播放失败, 则自动调用 TTS 朗读 [fallbackText]。
  Future<void> playAudioWithFallback({
    String? source,
    required String fallbackText,
  }) async {
    // 如果有音频源，尝试正常播放
    if (source != null && source.isNotEmpty) {
      try {
        await playAudio(source);
        return; // 播放成功，直接返回
      } catch (_) {
        // 播放失败，继续走 TTS fallback
      }
    }

    // Fallback: 使用 TTS 朗读文本
    if (_ttsService != null && fallbackText.isNotEmpty) {
      logger.info('使用 TTS Fallback 朗读: "$fallbackText"');
      await speakText(fallbackText);
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _player.pause();
      _currentState = AudioStateEnum.pause;
      logger.audioStateChange(newState: _currentState.name);
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '暂停音频失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentAudioSource = '';
      _currentState = AudioStateEnum.unplayed;

      logger.audioStateChange(newState: _currentState.name);
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '停止音频失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      logger.debug('跳转到: ${position.inSeconds}秒');
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '跳转音频失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      logger.debug('音量设置为: $volume');
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '设置音量失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 设置播放速度 (0.5 - 2.0)
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed.clamp(0.5, 2.0));
      logger.debug('播放速度设置为: $speed');
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '设置播放速度失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _currentState = AudioStateEnum.unplayed;
      _currentAudioSource = '';
      logger.audioStateChange(newState: _currentState.name);
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '释放音频服务失败: ${e.toString()}',
      );
    }
  }

  /// 对 URL 中的非 ASCII 字符进行 percent-encoding
  /// 保留 scheme、host、路径分隔符（/），只编码路径段中的非 ASCII 字符
  String _encodeUrl(String url) {
    return Uri.encodeFull(url);
  }
}

/// 未播放, 播放中, 暂停
enum AudioStateEnum { unplayed, playing, pause }

/// 基于内存中 WAV 数据的自定义音频源
///
/// 将合成的 WAV 字节数据包装成 just_audio 可识别的 AudioSource。
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _wavBytes;

  _WavAudioSource(this._wavBytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _wavBytes.length;

    return StreamAudioResponse(
      sourceLength: _wavBytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_wavBytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
