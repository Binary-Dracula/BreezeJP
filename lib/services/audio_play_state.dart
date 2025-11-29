/// 音频播放状态枚举
enum AudioPlayState {
  /// 空闲（未播放）
  idle,

  /// 加载中
  loading,

  /// 播放中
  playing,

  /// 错误
  error,
}

/// 音频播放状态数据
class AudioPlayStatus {
  final AudioPlayState state;
  final String? currentSource;
  final String? errorMessage;

  const AudioPlayStatus({
    this.state = AudioPlayState.idle,
    this.currentSource,
    this.errorMessage,
  });

  /// 判断指定音频是否正在播放
  bool isPlaying(String source) =>
      state == AudioPlayState.playing && currentSource == source;

  /// 判断指定音频是否正在加载
  bool isLoading(String source) =>
      state == AudioPlayState.loading && currentSource == source;

  /// 是否处于空闲状态
  bool get isIdle => state == AudioPlayState.idle;

  /// 是否有错误
  bool get hasError => state == AudioPlayState.error;

  AudioPlayStatus copyWith({
    AudioPlayState? state,
    String? currentSource,
    String? errorMessage,
  }) {
    return AudioPlayStatus(
      state: state ?? this.state,
      currentSource: currentSource ?? this.currentSource,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
