# 音频 URL 功能迁移指南

## 概述

数据库中的 `word_audio` 和 `example_audio` 表新增了 `audio_url` 列，用于支持在线音频播放。

## 数据库变更

### word_audio 表

```sql
ALTER TABLE word_audio ADD COLUMN audio_url TEXT;
```

| 字段 | 类型 | 描述 |
|------|------|------|
| audio_url | TEXT | 音频文件的 URL 地址（可选） |

### example_audio 表

```sql
ALTER TABLE example_audio ADD COLUMN audio_url TEXT;
```

| 字段 | 类型 | 描述 |
|------|------|------|
| audio_url | TEXT | 音频文件的 URL 地址（可选） |

## 代码变更

### 1. 数据模型更新

#### WordAudio 模型

```dart
class WordAudio {
  final int id;
  final int wordId;
  final String audioFilename;
  final String? audioUrl;  // ✅ 新增字段
  final String? voiceType;
  final String? source;

  WordAudio({
    required this.id,
    required this.wordId,
    required this.audioFilename,
    this.audioUrl,  // ✅ 新增参数
    this.voiceType,
    this.source,
  });

  factory WordAudio.fromMap(Map<String, dynamic> map) {
    return WordAudio(
      id: map['id'],
      wordId: map['word_id'],
      audioFilename: map['audio_filename'],
      audioUrl: map['audio_url'],  // ✅ 新增映射
      voiceType: map['voice_type'],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'audio_filename': audioFilename,
      'audio_url': audioUrl,  // ✅ 新增映射
      'voice_type': voiceType,
      'source': source,
    };
  }
}
```

#### ExampleAudio 模型

```dart
class ExampleAudio {
  final int id;
  final int exampleId;
  final String audioFilename;
  final String? audioUrl;  // ✅ 新增字段
  final String? voiceType;
  final String? source;

  ExampleAudio({
    required this.id,
    required this.exampleId,
    required this.audioFilename,
    this.audioUrl,  // ✅ 新增参数
    this.voiceType,
    this.source,
  });

  factory ExampleAudio.fromMap(Map<String, dynamic> map) {
    return ExampleAudio(
      id: map['id'],
      exampleId: map['example_id'],
      audioFilename: map['audio_filename'],
      audioUrl: map['audio_url'],  // ✅ 新增映射
      voiceType: map['voice_type'],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'example_id': exampleId,
      'audio_filename': audioFilename,
      'audio_url': audioUrl,  // ✅ 新增映射
      'voice_type': voiceType,
      'source': source,
    };
  }
}
```

### 2. 新增 AudioService

创建了统一的音频播放服务，支持本地和在线音频：

```dart
// lib/services/audio_service.dart
class AudioService {
  /// 播放单词音频（自动处理 URL 和本地文件）
  Future<void> playWordAudio(WordAudio audio) async { ... }

  /// 播放例句音频（自动处理 URL 和本地文件）
  Future<void> playExampleAudio(ExampleAudio audio) async { ... }
}
```

### 3. Controller 更新

#### WordDetailController

```dart
// ✅ 新增音频播放方法
Future<void> playWordAudio(WordAudio audio) async {
  await _audioService.playWordAudio(audio);
}

Future<void> playExampleAudio(ExampleAudio audio) async {
  await _audioService.playExampleAudio(audio);
}
```

#### LearnController

```dart
// ✅ 使用 AudioService 替代直接使用 AudioPlayer
get _audioService => ref.read(audioServiceProvider);

Future<void> playWordAudio() async {
  final audio = currentWord.audios.first;
  await _audioService.playWordAudio(audio);
}

Future<void> playExampleAudio(int exampleIndex) async {
  final audio = currentWord.examples[exampleIndex].audio;
  await _audioService.playExampleAudio(audio);
}
```

## 音频源优先级与回退机制

AudioService 使用智能回退策略，确保音频播放的可靠性：

1. **优先尝试 audioUrl** - 如果存在且不为空，先尝试加载在线音频
2. **回退到 audioFilename** - 如果在线音频失败或不存在，尝试本地资源文件
3. **错误处理** - 如果两者都失败，抛出异常并记录日志

```dart
// 示例 1: 在线优先，本地备份（推荐）
WordAudio(
  audioUrl: 'https://cdn.example.com/audio.mp3',  // ✅ 优先尝试
  audioFilename: 'fallback.mp3',  // ✅ 在线失败时使用
)

// 示例 2: 仅使用本地音频
WordAudio(
  audioUrl: null,
  audioFilename: 'local_audio.mp3',  // ✅ 直接使用本地文件
)

// 示例 3: 仅使用在线音频（本地不存在）
WordAudio(
  audioUrl: 'https://cdn.example.com/audio.mp3',  // ✅ 使用在线
  audioFilename: 'not_exist.mp3',  // ⚠️ 本地不存在，但不影响播放
)
```

**回退流程**：
```
尝试在线音频 (audioUrl)
    ↓ 失败
尝试本地音频 (audioFilename)
    ↓ 失败
抛出异常
```

## 迁移步骤

### 1. 更新数据库

如果使用现有数据库，需要执行迁移：

```dart
// 在 AppDatabase 中添加迁移逻辑
Future<void> _migrateDatabase(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // 添加 audio_url 列
    await db.execute('ALTER TABLE word_audio ADD COLUMN audio_url TEXT');
    await db.execute('ALTER TABLE example_audio ADD COLUMN audio_url TEXT');
  }
}
```

### 2. 更新代码

所有使用音频的地方都应该使用 AudioService：

```dart
// ❌ 旧方式：直接使用 AudioPlayer
final player = AudioPlayer();
await player.setAsset('assets/audio/words/file.mp3');
await player.play();

// ✅ 新方式：使用 AudioService
final audioService = ref.read(audioServiceProvider);
await audioService.playWordAudio(wordAudio);
```

### 3. 更新 UI

在 UI 中调用 Controller 的音频播放方法：

```dart
// 播放单词音频
IconButton(
  icon: Icon(Icons.volume_up),
  onPressed: () {
    final audio = word.primaryAudio;
    if (audio != null) {
      ref.read(wordDetailControllerProvider.notifier)
         .playWordAudio(audio);
    }
  },
)

// 播放例句音频
IconButton(
  icon: Icon(Icons.volume_up),
  onPressed: () {
    final audio = example.audio;
    if (audio != null) {
      ref.read(wordDetailControllerProvider.notifier)
         .playExampleAudio(audio);
    }
  },
)
```

## 向后兼容性

- 现有的本地音频文件继续正常工作
- `audioUrl` 字段为可选，不影响现有数据
- 旧的 `primaryAudioPath` 和 `audioPath` 方法标记为 `@Deprecated`，但仍可使用

## 使用场景

### 场景 1: 纯本地音频

```dart
WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: '高校_koukou_default_default.mp3',
  audioUrl: null,  // 不使用在线音频
)
```

### 场景 2: 纯在线音频

```dart
WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: 'placeholder.mp3',  // 保留字段，但不使用
  audioUrl: 'https://cdn.example.com/audio/koukou.mp3',
)
```

### 场景 3: 混合模式（推荐）

```dart
WordAudio(
  id: 1,
  wordId: 100,
  audioFilename: '高校_koukou_default_default.mp3',  // 本地备份
  audioUrl: 'https://cdn.example.com/audio/koukou.mp3',  // 优先使用
)
```

## 优势

1. **灵活性**：支持本地和在线音频
2. **性能优化**：可以使用 CDN 加速音频加载
3. **存储优化**：减少 APK 体积，音频按需下载
4. **更新便利**：无需发布新版本即可更新音频
5. **降级支持**：在线音频失败时可回退到本地文件

## 注意事项

1. **网络权限**：使用在线音频需要网络权限
2. **错误处理**：在线音频可能因网络问题加载失败
3. **缓存策略**：考虑实现音频缓存以提升用户体验
4. **数据流量**：提醒用户在线播放会消耗流量

## 后续优化建议

1. **音频缓存**：实现本地缓存机制，避免重复下载
2. **预加载**：在 WiFi 环境下预加载常用音频
3. **离线模式**：提供离线模式开关
4. **下载管理**：允许用户批量下载音频到本地
5. **质量选择**：提供不同音质的音频选项
