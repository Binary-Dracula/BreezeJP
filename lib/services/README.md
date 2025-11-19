# Services 服务层

## 概述

Services 层提供应用级别的业务逻辑服务，独立于 UI 和数据层。

## 音频服务 (AudioService)

### 功能特性

- 支持本地资源文件播放（assets）
- 支持在线 URL 音频播放
- 统一的音频播放接口
- 自动资源管理

### 使用方式

#### 1. 在 Controller 中使用

```dart
import '../../../services/audio_service_provider.dart';

class MyController extends Notifier<MyState> {
  // 获取音频服务
  get _audioService => ref.read(audioServiceProvider);

  Future<void> playAudio(WordAudio audio) async {
    await _audioService.playWordAudio(audio);
  }
}
```

#### 2. 播放单词音频

```dart
// 自动处理 audioUrl 和 audioFilename
final wordAudio = WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: '高校_koukou_default_default.mp3',
  audioUrl: 'https://example.com/audio/word.mp3', // 可选
  voiceType: 'default',
  source: 'default',
);

await audioService.playWordAudio(wordAudio);
```

#### 3. 播放例句音频

```dart
final exampleAudio = ExampleAudio(
  id: 1,
  exampleId: 50,
  audioFilename: 'sentence_1_default_default.mp3',
  audioUrl: 'https://example.com/audio/example.mp3', // 可选
  voiceType: 'default',
  source: 'default',
);

await audioService.playExampleAudio(exampleAudio);
```

#### 4. 控制播放

```dart
// 暂停
await audioService.pause();

// 停止
await audioService.stop();

// 跳转
await audioService.seek(Duration(seconds: 5));

// 设置音量 (0.0 - 1.0)
await audioService.setVolume(0.8);

// 设置播放速度 (0.5 - 2.0)
await audioService.setSpeed(1.5);
```

### 音频播放策略

**当前策略：仅使用在线音频**

AudioService 当前配置为仅播放在线音频，不使用本地资源文件：

1. **检查 audioUrl** - 如果存在且不为空，播放在线音频
2. **没有 audioUrl** - 跳过播放，抛出异常

```dart
// ✅ 有在线音频 - 正常播放
WordAudio(
  audioUrl: 'https://cdn.example.com/audio.mp3',  // ✅ 播放在线音频
  audioFilename: 'placeholder.mp3',  // ⚠️ 不使用本地文件
)

// ❌ 没有在线音频 - 跳过播放
WordAudio(
  audioUrl: null,  // 没有在线音频
  audioFilename: 'local_audio.mp3',  // ⚠️ 本地文件不会被使用
)
// 结果: 抛出异常 "没有可用的在线音频"
```

**播放流程**：
1. 检查 `audioUrl` 是否存在
   ├─ 存在 → 播放在线音频 ✅
   └─ 不存在 → 抛出异常 ❌

**注意事项**：
- 本地音频文件（`audioFilename`）暂时不会被使用
- 所有音频必须有有效的 `audioUrl` 才能播放
- 如需恢复本地音频支持，可修改 `_playAudioWithFallback` 方法

### 本地音频路径规则

- 单词音频：`assets/audio/words/[audioFilename]`
- 例句音频：`assets/audio/examples/[audioFilename]`

### 资源管理

AudioService 通过 Riverpod Provider 自动管理：

```dart
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  
  // 当 Provider 被销毁时，自动释放资源
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});
```

### 错误处理

```dart
try {
  await audioService.playWordAudio(audio);
} catch (e) {
  logger.error('播放音频失败', e);
  // 处理错误（显示提示等）
}
```

### 监听播放状态

```dart
// 在 Controller 中监听播放状态
audioService.player.playerStateStream.listen((state) {
  if (state.processingState == ProcessingState.completed) {
    // 播放完成
  }
  if (state.playing) {
    // 正在播放
  }
});

// 监听播放位置
audioService.player.positionStream.listen((position) {
  // 更新进度条
});

// 监听总时长
audioService.player.durationStream.listen((duration) {
  // 显示总时长
});
```

## 最佳实践

### 1. 使用 Provider 访问服务

```dart
// ✅ 推荐：通过 Provider
get _audioService => ref.read(audioServiceProvider);

// ❌ 不推荐：直接创建实例
final audioService = AudioService(); // 会导致资源泄漏
```

### 2. 在 Controller 中管理音频

```dart
class WordDetailController extends Notifier<WordDetailState> {
  get _audioService => ref.read(audioServiceProvider);

  Future<void> playAudio(WordAudio audio) async {
    try {
      await _audioService.playWordAudio(audio);
    } catch (e) {
      state = state.copyWith(error: '播放失败');
    }
  }
}
```

### 3. 切换页面时停止音频

```dart
@override
void dispose() {
  _audioService.stop();
  super.dispose();
}
```

### 4. 避免同时播放多个音频

```dart
// 播放新音频前先停止当前音频
await _audioService.stop();
await _audioService.playWordAudio(newAudio);
```

## 扩展功能

### 添加新的音频类型

如需支持其他类型的音频，可以扩展 AudioService：

```dart
class AudioService {
  // 添加新方法
  Future<void> playCustomAudio(String source) async {
    await _playAudio(source);
  }
}
```

### 添加播放列表功能

```dart
class AudioService {
  final List<String> _playlist = [];
  int _currentIndex = 0;

  Future<void> playPlaylist(List<String> sources) async {
    _playlist.clear();
    _playlist.addAll(sources);
    _currentIndex = 0;
    await _playNext();
  }

  Future<void> _playNext() async {
    if (_currentIndex < _playlist.length) {
      await _playAudio(_playlist[_currentIndex]);
      _currentIndex++;
    }
  }
}
```

## 注意事项

1. **资源释放**：AudioService 由 Provider 管理，会自动释放资源
2. **并发播放**：同一时间只能播放一个音频
3. **网络音频**：使用 URL 时需要网络权限和网络连接
4. **错误处理**：始终使用 try-catch 处理播放错误
5. **状态同步**：在 Controller 中维护播放状态，与 UI 同步
