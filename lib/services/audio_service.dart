import 'package:just_audio/just_audio.dart';
import '../core/utils/app_logger.dart';

/// 音频播放服务
/// 负责处理单词和例句的音频播放
/// 支持本地资源文件和在线 URL 音频
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioService();

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
      logger.warning('音频源为空');
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

      if (source.startsWith('http://') || source.startsWith('https://')) {
        final encodedUrl = _encodeUrl(source);
        await _player.setUrl(
          encodedUrl,
          headers: {'X-Breeze-Token': 'BreezeJP-2026-Secret-V1'},
        );
      } else {
        await _player.setAsset(source);
      }

      await _player.play();
      _currentState = AudioStateEnum.playing;
      logger.audioStateChange(newState: _currentState.name);
    } catch (e) {
      logger.warning('播放音频失败: $source, 错误: $e');
      _currentState = AudioStateEnum.unplayed;
      rethrow;
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
    } catch (e) {
      logger.audioPlayError(
        audio: _currentAudioSource,
        errorType: e.runtimeType.toString(),
        errorMessage: '释放音频服务失败: ${e.toString()}',
      );
    }
  }

  String _encodeUrl(String url) {
    return Uri.encodeFull(url);
  }
}

/// 未播放, 播放中, 暂停
enum AudioStateEnum { unplayed, playing, pause }
