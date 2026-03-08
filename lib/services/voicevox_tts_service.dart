import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:voicevox_core/voicevox_core.dart';

import 'tts_service.dart';
import '../core/utils/app_logger.dart';

/// Voicevox Core 实现的离线日语 TTS 服务
///
/// 初始化流程:
/// 1. 首次启动时将 Flutter assets 中的字典/模型拷贝到应用沙盒
/// 2. 加载 ONNX Runtime (iOS 静态链接 / Android 动态加载)
/// 3. 创建 OpenJTalk 实例 (日语形态素解析)
/// 4. 创建 Synthesizer 并加载语音模型
class VoicevoxTtsService implements TtsService {
  // ---- 原生指针 ----
  Pointer<VoicevoxSynthesizer>? _synthesizer;
  Pointer<OpenJtalkRc>? _openJtalk;
  Pointer<VoicevoxOnnxruntime>? _onnxruntime;

  // ---- 状态 ----
  bool _isInitialized = false;
  double _speed = 1.0;

  // ---- 资源文件 ----
  /// OpenJTalk 字典文件列表 (需与 assets/tts/voicevox/dict/ 目录一致)
  static const _dictFiles = [
    'char.bin',
    'COPYING',
    'left-id.def',
    'matrix.bin',
    'pos-id.def',
    'rewrite.def',
    'right-id.def',
    'sys.dic',
    'unk.dic',
  ];

  /// VVM 模型文件名
  static const _modelFileName = '0.vvm';

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logger.info('正在初始化 Voicevox TTS 引擎...');

      // 0. 配置平台特定的动态库文件名
      // 必须在任何 voicevox_core 函数调用之前设置,
      // 因为 _libCore 在首次访问时就会加载
      _configurePlatformLibrary();

      // 1. 准备资源: 从 assets 拷贝到本地沙盒
      final docDir = await getApplicationDocumentsDirectory();
      final dictPath = p.join(docDir.path, 'tts', 'voicevox', 'dict');
      final modelPath = p.join(
        docDir.path,
        'tts',
        'voicevox',
        'model',
        _modelFileName,
      );

      await _prepareResources(dictPath, modelPath);

      // 2. 加载 ONNX Runtime
      _onnxruntime = await _initOnnxRuntime();
      logger.info('ONNX Runtime 加载成功');

      // 3. 初始化 Open JTalk (日语形态素解析器)
      _openJtalk = _initOpenJtalk(dictPath);
      logger.info('Open JTalk 初始化成功');

      // 4. 创建 Synthesizer (合成器)
      _synthesizer = _createSynthesizer(_onnxruntime!, _openJtalk!);
      logger.info('Synthesizer 创建成功');

      // 5. 加载语音模型 (VVM)
      _loadVoiceModel(_synthesizer!, modelPath);
      logger.info('语音模型加载成功: $_modelFileName');

      _isInitialized = true;
      logger.info('Voicevox TTS 引擎初始化完成 ✓');
    } catch (e, stack) {
      logger.error('Voicevox 初始化异常', e, stack);
      // 初始化失败时清理已分配的资源
      await _cleanupOnError();
      rethrow;
    }
  }

  @override
  Future<Uint8List> synthesize(String text, {int styleId = 4}) async {
    if (!_isInitialized || _synthesizer == null) {
      await initialize();
    }

    // 清理文本: 去掉 [ふりがな] 标注,
    // 例如 "今[いま]" → "今", TTS 引擎会自行处理汉字读音
    final cleanText = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    logger.debug('开始合成语音: "$cleanText" (styleId=$styleId)');

    // 在后台 Isolate 中执行阻塞式 FFI 合成,
    // 避免卡住主线程 UI (合成耗时约 1-3 秒)
    // 注意: 必须在闭包外提取 address, 避免闭包捕获 this
    // 注意: Isolate 有独立的单例状态, 需要传入库名在 Isolate 内重新配置
    final synthAddress = _synthesizer!.address;
    final coreLibName = VoicevoxCoreDynamicLibraryService().entries['core']!;
    final wavBytes = await Isolate.run(() {
      return _synthesizeInIsolate(
        synthAddress,
        cleanText,
        styleId,
        coreLibName,
      );
    });

    logger.debug('语音合成完成, WAV 大小: ${wavBytes.length} bytes');
    return wavBytes;
  }

  /// 在 Isolate 中执行 FFI 合成 (阻塞操作)
  ///
  /// 由于 Pointer 不能跨 Isolate 传递,
  /// 使用整数地址重建指针。
  static Uint8List _synthesizeInIsolate(
    int synthesizerAddress,
    String text,
    int styleId,
    String coreLibName,
  ) {
    // 每个 Isolate 有独立的单例, 需重新配置动态库名
    VoicevoxCoreDynamicLibraryService().set('core', coreLibName);

    final synthesizer = Pointer<VoicevoxSynthesizer>.fromAddress(
      synthesizerAddress,
    );
    final ttsOptions = voicevoxMakeDefaultTtsOptions();
    final Pointer<Uint64> outWavLength = calloc<Uint64>();
    final Pointer<Pointer<Uint8>> outWav = calloc<Pointer<Uint8>>();

    try {
      final result = voicevoxSynthesizerTts(
        synthesizer,
        text,
        styleId,
        ttsOptions,
        outWavLength,
        outWav,
      );

      if (result != 0) {
        final errorMsg = voicevoxErrorResultToMessage(result);
        throw Exception('Voicevox 合成失败 (code=$result): $errorMsg');
      }

      final length = outWavLength.value;
      // 将 C 层 WAV 数据拷贝到 Dart 管理的内存
      final Uint8List wavBytes = Uint8List.fromList(
        outWav.value.asTypedList(length),
      );

      // 释放 C 层分配的 WAV 内存
      voicevoxWavFree(outWav.value);

      return wavBytes;
    } finally {
      calloc.free(outWavLength);
      calloc.free(outWav);
    }
  }

  @override
  Future<void> stop() async {
    // 播放由 AudioService 管理, 此处无需操作
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
  }

  @override
  double get speed => _speed;

  @override
  Future<void> dispose() async {
    if (_synthesizer != null) {
      voicevoxSynthesizerDelete(_synthesizer!);
      _synthesizer = null;
    }
    if (_openJtalk != null) {
      voicevoxOpenJtalkRcDelete(_openJtalk!);
      _openJtalk = null;
    }
    // onnxruntime 是全局单例，由 voicevox_core 管理生命周期，不需手动释放
    _onnxruntime = null;
    _isInitialized = false;

    logger.info('Voicevox TTS 引擎已释放');
  }

  // ========== 私有方法: 初始化子步骤 ==========

  /// 配置平台特定的动态库文件名
  ///
  /// Android 的 jniLibs 中 .so 文件必须带有 `lib` 前缀,
  /// 但 voicevox_core 包默认生成的文件名不带前缀,
  /// 因此需要在首次 FFI 调用前手动修正。
  void _configurePlatformLibrary() {
    final libService = VoicevoxCoreDynamicLibraryService();

    if (Platform.isAndroid) {
      // Android: jniLibs 中的 .so 带 lib 前缀
      libService.set('core', 'libvoicevox_core.so');
    } else if (Platform.isIOS) {
      // iOS: xcframework 中的 framework 不需要前缀
      libService.set('core', 'voicevox_core.framework/voicevox_core');
    }
    // macOS / Linux / Windows 使用默认值即可

    logger.debug('动态库配置: ${libService.entries}');
  }

  /// 加载 ONNX Runtime
  ///
  /// iOS: 使用 voicevoxOnnxruntimeInitOnce (xcframework 静态链接了 ONNX Runtime)
  /// Android/其他: 使用 voicevoxOnnxruntimeLoadOnce (动态加载 .so)
  Future<Pointer<VoicevoxOnnxruntime>> _initOnnxRuntime() async {
    final Pointer<Pointer<VoicevoxOnnxruntime>> outOnnx =
        calloc<Pointer<VoicevoxOnnxruntime>>();

    try {
      int result;
      if (Platform.isIOS) {
        // iOS: ONNX Runtime 已静态链接到 xcframework 中
        result = voicevoxOnnxruntimeInitOnce(outOnnx);
      } else {
        // Android / macOS / 其他: 动态加载 ONNX Runtime 动态库
        final options = voicevoxMakeDefaultLoadOnnxruntimeOptions();
        result = voicevoxOnnxruntimeLoadOnce(options, outOnnx);
      }

      if (result != 0) {
        final errorMsg = voicevoxErrorResultToMessage(result);
        throw Exception('加载 ONNX Runtime 失败 (code=$result): $errorMsg');
      }

      return outOnnx.value;
    } finally {
      calloc.free(outOnnx);
    }
  }

  /// 初始化 Open JTalk (日语文本解析器)
  Pointer<OpenJtalkRc> _initOpenJtalk(String dictPath) {
    final Pointer<Pointer<OpenJtalkRc>> outJtalk =
        calloc<Pointer<OpenJtalkRc>>();

    try {
      final result = voicevoxOpenJtalkRcNew(dictPath, outJtalk);
      if (result != 0) {
        final errorMsg = voicevoxErrorResultToMessage(result);
        throw Exception(
          '初始化 Open JTalk 失败 (code=$result): $errorMsg\n字典路径: $dictPath',
        );
      }
      return outJtalk.value;
    } finally {
      calloc.free(outJtalk);
    }
  }

  /// 创建 Voicevox Synthesizer
  Pointer<VoicevoxSynthesizer> _createSynthesizer(
    Pointer<VoicevoxOnnxruntime> onnxRuntime,
    Pointer<OpenJtalkRc> openJtalk,
  ) {
    final Pointer<Pointer<VoicevoxSynthesizer>> outSynth =
        calloc<Pointer<VoicevoxSynthesizer>>();

    try {
      final options = voicevoxMakeDefaultInitializeOptions();
      final result = voicevoxSynthesizerNew(
        onnxRuntime,
        openJtalk,
        options,
        outSynth,
      );

      if (result != 0) {
        final errorMsg = voicevoxErrorResultToMessage(result);
        throw Exception('创建 Synthesizer 失败 (code=$result): $errorMsg');
      }
      return outSynth.value;
    } finally {
      calloc.free(outSynth);
    }
  }

  /// 加载语音模型 (VVM 文件) 到 Synthesizer
  void _loadVoiceModel(
    Pointer<VoicevoxSynthesizer> synthesizer,
    String modelPath,
  ) {
    final Pointer<Pointer<VoicevoxVoiceModelFile>> outModel =
        calloc<Pointer<VoicevoxVoiceModelFile>>();

    try {
      // 打开模型文件
      final openResult = voicevoxVoiceModelFileOpen(modelPath, outModel);
      if (openResult != 0) {
        final errorMsg = voicevoxErrorResultToMessage(openResult);
        throw Exception(
          '打开语音模型文件失败 (code=$openResult): $errorMsg\n路径: $modelPath',
        );
      }

      final modelFile = outModel.value;

      // 将模型加载到 Synthesizer 中
      final loadResult = voicevoxSynthesizerLoadVoiceModel(
        synthesizer,
        modelFile,
      );

      // 无论成功与否，都关闭模型文件句柄
      voicevoxVoiceModelFileDelete(modelFile);

      if (loadResult != 0) {
        final errorMsg = voicevoxErrorResultToMessage(loadResult);
        final modelFile2 = File(modelPath);
        final fileSize = modelFile2.existsSync() ? modelFile2.lengthSync() : 0;
        throw Exception(
          '加载语音模型到 Synthesizer 失败 (code=$loadResult): $errorMsg\n'
          '路径: $modelPath, 大小: $fileSize bytes',
        );
      }
    } finally {
      calloc.free(outModel);
    }
  }

  // ========== 私有方法: 资源管理 ==========

  /// 将 Flutter assets 中的 TTS 资源拷贝到应用沙盒
  ///
  /// 底层 C/C++ 引擎 (FFI) 无法直接读取 APK/IPA 包内的文件,
  /// 因此需要在首次启动时拷贝到可直接通过文件路径访问的沙盒目录。
  /// 使用标记文件 (.ready) 防止重复拷贝。
  Future<void> _prepareResources(String dictPath, String modelPath) async {
    final dictDir = Directory(dictPath);
    final modelDir = Directory(p.dirname(modelPath));

    // 使用标记文件判断是否已经拷贝过
    final readyFlag = File(p.join(dictDir.parent.path, '.ready'));
    if (readyFlag.existsSync()) {
      logger.debug('TTS 资源已经就绪，跳过拷贝');
      return;
    }

    logger.info('首次初始化：正在提取 TTS 资源到沙盒...');

    // 创建目标目录
    await dictDir.create(recursive: true);
    await modelDir.create(recursive: true);

    // 拷贝字典文件
    for (final fileName in _dictFiles) {
      final assetPath = 'assets/tts/voicevox/dict/$fileName';
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(p.join(dictPath, fileName)).writeAsBytes(bytes, flush: true);
        logger.debug('拷贝字典文件: $fileName (${bytes.length} bytes)');
      } catch (e) {
        throw Exception('拷贝字典文件失败: $assetPath → $e');
      }
    }

    // 拷贝模型文件
    final modelAssetPath = 'assets/tts/voicevox/model/$_modelFileName';
    try {
      final data = await rootBundle.load(modelAssetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(modelPath).writeAsBytes(bytes, flush: true);
      logger.info('拷贝模型文件: $_modelFileName (${bytes.length} bytes)');
    } catch (e) {
      throw Exception('拷贝模型文件失败: $modelAssetPath → $e');
    }

    // 写入标记文件
    await readyFlag.writeAsString(
      'extracted_at=${DateTime.now().toIso8601String()}',
    );
    logger.info('TTS 资源提取完成 ✓');
  }

  /// 初始化失败时清理已分配的原生资源
  Future<void> _cleanupOnError() async {
    if (_synthesizer != null) {
      voicevoxSynthesizerDelete(_synthesizer!);
      _synthesizer = null;
    }
    if (_openJtalk != null) {
      voicevoxOpenJtalkRcDelete(_openJtalk!);
      _openJtalk = null;
    }
    _onnxruntime = null;
    _isInitialized = false;
  }
}
