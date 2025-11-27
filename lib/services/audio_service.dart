import 'package:just_audio/just_audio.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/l10n_utils.dart';
import '../data/models/word_audio.dart';
import '../data/models/example_audio.dart';

/// 音频播放服务
/// 负责处理单词和例句的音频播放
/// 支持本地资源文件和在线 URL 音频
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentAudioSource;
  String _currentState = 'stopped'; // 当前播放状态: stopped, playing, paused
  DateTime? _playStartTime; // 播放开始时间，用于计算播放时长

  /// 获取播放器实例
  AudioPlayer get player => _player;

  /// 当前播放的音频源
  String? get currentAudioSource => _currentAudioSource;

  /// 播放单词音频
  /// 优先使用 audioUrl，如果不存在则使用本地 audioFilename
  Future<void> playWordAudio(WordAudio audio, {int? wordId}) async {
    final source = audio.audioUrl ?? audio.audioFilename;
    try {
      logger.audioPlayStart(sourceType: 'word', source: source, wordId: wordId);
      await _playAudioWithFallback(
        audioUrl: audio.audioUrl,
        audioFilename: audio.audioFilename,
        isWordAudio: true,
      );
    } catch (e) {
      logger.audioPlayError(
        source: source,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// 播放例句音频
  /// 优先使用 audioUrl，如果不存在则使用本地 audioFilename
  Future<void> playExampleAudio(ExampleAudio audio, {int? wordId}) async {
    final source = audio.audioUrl ?? audio.audioFilename;
    try {
      logger.audioPlayStart(
        sourceType: 'example',
        source: source,
        wordId: wordId,
      );
      await _playAudioWithFallback(
        audioUrl: audio.audioUrl,
        audioFilename: audio.audioFilename,
        isWordAudio: false,
      );
    } catch (e) {
      logger.audioPlayError(
        source: source,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// 根据文件名或 URL 播放音频
  Future<void> playAudioBySource(String source, {int? wordId}) async {
    try {
      logger.audioPlayStart(
        sourceType: 'unknown',
        source: source,
        wordId: wordId,
      );
      await _playAudio(source);
    } catch (e) {
      logger.audioPlayError(
        source: source,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    try {
      final previousState = _currentState;
      await _player.pause();
      _currentState = 'paused';
      logger.audioStateChange(
        previousState: previousState,
        newState: _currentState,
      );
    } catch (e) {
      logger.audioPlayError(
        source: _currentAudioSource ?? 'unknown',
        errorType: e.runtimeType.toString(),
        errorMessage: '暂停音频失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      final previousState = _currentState;
      final source = _currentAudioSource;
      await _player.stop();
      _currentState = 'stopped';
      _currentAudioSource = null;

      // 记录播放完成（如果有播放开始时间）
      if (_playStartTime != null && source != null) {
        final durationMs = DateTime.now()
            .difference(_playStartTime!)
            .inMilliseconds;
        logger.audioPlayComplete(source: source, durationMs: durationMs);
        _playStartTime = null;
      }

      logger.audioStateChange(
        previousState: previousState,
        newState: _currentState,
      );
    } catch (e) {
      logger.audioPlayError(
        source: _currentAudioSource ?? 'unknown',
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
        source: _currentAudioSource ?? 'unknown',
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
        source: _currentAudioSource ?? 'unknown',
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
        source: _currentAudioSource ?? 'unknown',
        errorType: e.runtimeType.toString(),
        errorMessage: '设置播放速度失败: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      final previousState = _currentState;
      await _player.dispose();
      _currentState = 'stopped';
      _currentAudioSource = null;
      _playStartTime = null;
      logger.audioStateChange(
        previousState: previousState,
        newState: 'disposed',
      );
    } catch (e) {
      logger.audioPlayError(
        source: _currentAudioSource ?? 'unknown',
        errorType: e.runtimeType.toString(),
        errorMessage: '释放音频服务失败: ${e.toString()}',
      );
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
    // 仅使用在线音频
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        final previousState = _currentState;

        // 如果是同一个音频源，重新播放
        if (_currentAudioSource == audioUrl) {
          await _player.seek(Duration.zero);
          _playStartTime = DateTime.now();
          await _player.play();
          _currentState = 'playing';
          logger.audioStateChange(
            previousState: previousState,
            newState: _currentState,
          );
          return;
        }

        // 不同音频源，先停止再加载
        if (_player.playing) {
          await _player.stop();
        }

        _currentAudioSource = audioUrl;
        _playStartTime = DateTime.now();
        await _player.setUrl(audioUrl);
        await _player.play();
        _currentState = 'playing';
        logger.audioStateChange(
          previousState: previousState,
          newState: _currentState,
        );
        return;
      } catch (e) {
        _currentAudioSource = null;
        _playStartTime = null;
        _currentState = 'stopped';
        throw Exception(l10n.audioLoadFailedOnline(audioUrl));
      }
    }

    // 没有在线音频，跳过播放
    throw Exception(l10n.audioNoOnlineSource(audioFilename));
  }

  /// 播放音频
  Future<void> _playAudio(String source) async {
    try {
      final previousState = _currentState;

      // 如果是同一个音频源，重新播放
      if (_currentAudioSource == source) {
        await _player.seek(Duration.zero);
        _playStartTime = DateTime.now();
        await _player.play();
        _currentState = 'playing';
        logger.audioStateChange(
          previousState: previousState,
          newState: _currentState,
        );
        return;
      }

      // 不同音频源，先停止再加载
      if (_player.playing) {
        await _player.stop();
      }

      _currentAudioSource = source;
      _playStartTime = DateTime.now();

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
      _currentState = 'playing';
      logger.audioStateChange(
        previousState: previousState,
        newState: _currentState,
      );
    } catch (e) {
      _currentAudioSource = null;
      _playStartTime = null;
      _currentState = 'stopped';
      rethrow;
    }
  }
}
