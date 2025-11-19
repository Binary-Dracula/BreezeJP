import 'package:just_audio/just_audio.dart';
import '../core/utils/app_logger.dart';
import '../data/models/word_audio.dart';
import '../data/models/example_audio.dart';

/// 音频播放服务
/// 负责处理单词和例句的音频播放
/// 支持本地资源文件和在线 URL 音频
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentAudioSource;

  /// 获取播放器实例
  AudioPlayer get player => _player;

  /// 当前播放的音频源
  String? get currentAudioSource => _currentAudioSource;

  /// 播放单词音频
  /// 优先使用 audioUrl，如果不存在则使用本地 audioFilename
  Future<void> playWordAudio(WordAudio audio) async {
    try {
      await _playAudioWithFallback(
        audioUrl: audio.audioUrl,
        audioFilename: audio.audioFilename,
        isWordAudio: true,
      );
    } catch (e, stackTrace) {
      logger.error('播放单词音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 播放例句音频
  /// 优先使用 audioUrl，如果不存在则使用本地 audioFilename
  Future<void> playExampleAudio(ExampleAudio audio) async {
    try {
      await _playAudioWithFallback(
        audioUrl: audio.audioUrl,
        audioFilename: audio.audioFilename,
        isWordAudio: false,
      );
    } catch (e, stackTrace) {
      logger.error('播放例句音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 根据文件名或 URL 播放音频
  Future<void> playAudioBySource(String source) async {
    try {
      logger.info('播放音频: $source');
      await _playAudio(source);
    } catch (e, stackTrace) {
      logger.error('播放音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      await _player.pause();
      logger.debug('音频已暂停');
    } catch (e, stackTrace) {
      logger.error('暂停音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentAudioSource = null;
      logger.debug('音频已停止');
    } catch (e, stackTrace) {
      logger.error('停止音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      logger.debug('跳转到: ${position.inSeconds}秒');
    } catch (e, stackTrace) {
      logger.error('跳转音频失败', e, stackTrace);
      rethrow;
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      logger.debug('音量设置为: $volume');
    } catch (e, stackTrace) {
      logger.error('设置音量失败', e, stackTrace);
      rethrow;
    }
  }

  /// 设置播放速度 (0.5 - 2.0)
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed.clamp(0.5, 2.0));
      logger.debug('播放速度设置为: $speed');
    } catch (e, stackTrace) {
      logger.error('设置播放速度失败', e, stackTrace);
      rethrow;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _player.dispose();
      _currentAudioSource = null;
      logger.debug('音频服务已释放');
    } catch (e, stackTrace) {
      logger.error('释放音频服务失败', e, stackTrace);
    }
  }

  // ==================== 私有方法 ====================

  /// 播放音频（仅使用网络音频）
  /// 暂时只播放在线音频，不使用本地文件
  Future<void> _playAudioWithFallback({
    String? audioUrl,
    required String audioFilename,
    required bool isWordAudio,
  }) async {
    // 如果正在播放，先停止
    if (_player.playing) {
      await _player.stop();
    }

    // 仅使用在线音频
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        logger.info('播放在线音频: $audioUrl');
        _currentAudioSource = audioUrl;
        await _player.setUrl(audioUrl);
        await _player.play();
        logger.info('在线音频播放成功');
        return;
      } catch (e) {
        _currentAudioSource = null;
        logger.error('在线音频加载失败: $e');
        throw Exception('无法加载在线音频: $audioUrl');
      }
    }

    // 没有在线音频，跳过播放
    logger.warning('没有在线音频，跳过播放: $audioFilename');
    throw Exception('没有可用的在线音频: $audioFilename');
  }

  /// 播放音频
  Future<void> _playAudio(String source) async {
    try {
      // 如果正在播放，先停止
      if (_player.playing) {
        await _player.stop();
      }

      _currentAudioSource = source;

      // 判断是 URL 还是本地资源
      if (source.startsWith('http://') || source.startsWith('https://')) {
        // 在线音频
        await _player.setUrl(source);
      } else {
        // 本地资源
        await _player.setAsset(source);
      }

      // 开始播放
      await _player.play();
    } catch (e) {
      _currentAudioSource = null;
      rethrow;
    }
  }
}
