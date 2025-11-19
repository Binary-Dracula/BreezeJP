# 音频回退机制修复

## 问题描述

当本地音频文件不存在时，应用尝试加载本地 asset 导致错误：
```
Unable to load asset: "assets/audio/examples/sentence_5219_default_default.mp3"
The asset does not exist or has empty data.
```

## 问题原因

原始实现中，`AudioService` 会根据 `audioUrl` 是否存在来选择音频源，但没有处理本地文件不存在的情况。即使有 `audioUrl`，如果本地文件不存在，也会尝试加载本地 asset 并失败。

## 解决方案

实现了智能回退机制：

### 1. 新增 `_playAudioWithFallback` 方法

```dart
Future<void> _playAudioWithFallback({
  String? audioUrl,
  required String audioFilename,
  required bool isWordAudio,
}) async {
  // 策略 1: 优先尝试在线音频
  if (audioUrl != null && audioUrl.isNotEmpty) {
    try {
      await _player.setUrl(audioUrl);
      await _player.play();
      return; // 成功则返回
    } catch (e) {
      // 在线失败，继续尝试本地
    }
  }

  // 策略 2: 尝试本地音频
  try {
    await _player.setAsset(assetPath);
    await _player.play();
  } catch (e) {
    // 两者都失败，抛出异常
    throw Exception('音频文件不存在');
  }
}
```

### 2. 回退流程

```
1. 检查 audioUrl 是否存在
   ├─ 存在 → 尝试加载在线音频
   │         ├─ 成功 → 播放 ✅
   │         └─ 失败 → 继续步骤 2
   └─ 不存在 → 直接步骤 2

2. 尝试加载本地音频
   ├─ 成功 → 播放 ✅
   └─ 失败 → 抛出异常 ❌
```

## 使用场景

### 场景 1: 本地文件不存在，但有在线音频

```dart
ExampleAudio(
  audioFilename: 'sentence_5219_default_default.mp3',  // 本地不存在
  audioUrl: 'https://cdn.example.com/audio/sentence_5219.mp3',  // ✅ 使用在线
)
```

**结果**: 成功播放在线音频，不会尝试加载本地文件

### 场景 2: 在线音频失败，回退到本地

```dart
WordAudio(
  audioFilename: 'word_123.mp3',  // 本地存在
  audioUrl: 'https://cdn.example.com/audio/word_123.mp3',  // 网络失败
)
```

**结果**: 在线加载失败后，自动回退到本地音频

### 场景 3: 仅使用本地音频

```dart
WordAudio(
  audioFilename: 'word_456.mp3',  // 本地存在
  audioUrl: null,  // 不使用在线
)
```

**结果**: 直接加载本地音频

### 场景 4: 两者都不存在

```dart
WordAudio(
  audioFilename: 'not_exist.mp3',  // 本地不存在
  audioUrl: null,  // 没有在线音频
)
```

**结果**: 抛出异常 "音频文件不存在: not_exist.mp3"

## 日志输出

修复后的日志更加清晰：

```
✅ 成功场景（在线）:
[INFO] 尝试播放在线音频: https://cdn.example.com/audio.mp3
[INFO] 在线音频播放成功

✅ 成功场景（回退到本地）:
[INFO] 尝试播放在线音频: https://cdn.example.com/audio.mp3
[WARNING] 在线音频加载失败，尝试本地音频: NetworkException
[INFO] 尝试播放本地音频: assets/audio/words/word.mp3
[INFO] 本地音频播放成功

❌ 失败场景:
[INFO] 尝试播放本地音频: assets/audio/words/not_exist.mp3
[ERROR] 本地音频不存在且没有在线音频: assets/audio/words/not_exist.mp3
```

## 优势

1. **容错性强**: 在线失败自动回退到本地
2. **灵活性高**: 支持纯在线、纯本地、混合模式
3. **用户体验好**: 无需关心音频来源，自动选择最佳方案
4. **日志清晰**: 详细记录每一步操作，便于调试
5. **向后兼容**: 完全兼容现有代码

## 测试建议

### 1. 测试在线音频（本地不存在）

```dart
final audio = ExampleAudio(
  id: 1,
  exampleId: 5219,
  audioFilename: 'sentence_5219_default_default.mp3',
  audioUrl: 'https://example.com/audio/sentence_5219.mp3',
);

await audioService.playExampleAudio(audio);
// 预期: 成功播放在线音频
```

### 2. 测试回退机制

```dart
final audio = WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: 'existing_local.mp3',
  audioUrl: 'https://invalid-url.com/audio.mp3',  // 无效 URL
);

await audioService.playWordAudio(audio);
// 预期: 在线失败后，成功播放本地音频
```

### 3. 测试错误处理

```dart
final audio = WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: 'not_exist.mp3',
  audioUrl: null,
);

try {
  await audioService.playWordAudio(audio);
} catch (e) {
  print('预期的错误: $e');
  // 预期: 抛出 "音频文件不存在" 异常
}
```

## 相关文件

- `lib/services/audio_service.dart` - 核心修复
- `lib/services/README.md` - 文档更新
- `AUDIO_URL_MIGRATION.md` - 迁移指南更新
- `AUDIO_FALLBACK_FIX.md` - 本文档

## 总结

通过实现智能回退机制，AudioService 现在可以优雅地处理本地音频不存在的情况，优先使用在线音频，在线失败时自动回退到本地音频，大大提升了应用的健壮性和用户体验。
