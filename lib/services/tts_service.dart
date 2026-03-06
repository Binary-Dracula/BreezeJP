import 'dart:typed_data';

/// TTS 服务抽象接口
abstract class TtsService {
  /// 初始化引擎和载入模型/字典
  Future<void> initialize();

  /// 合成语音, 返回 WAV 音频数据
  ///
  /// [text] 朗读的日文文本
  /// [styleId] Voicevox 的音色样式 ID
  /// 返回合成的 WAV 格式音频字节数据
  Future<Uint8List> synthesize(String text, {int styleId = 0});

  /// 停止播放
  Future<void> stop();

  /// 设置速度 (0.5 - 2.0)
  Future<void> setSpeed(double speed);

  /// 释放资源
  Future<void> dispose();

  /// 判断是否已初始化
  bool get isInitialized;

  /// 当前语速
  double get speed;
}
