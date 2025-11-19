# 音频播放策略：仅在线模式

## 当前配置

AudioService 当前配置为**仅播放在线音频**，不使用本地资源文件。

## 行为说明

### ✅ 有在线音频 - 正常播放

```dart
WordAudio(
  audioUrl: 'https://cdn.example.com/audio/word.mp3',  // ✅ 播放
  audioFilename: 'word_123.mp3',  // ⚠️ 忽略
)
```

**结果**: 成功播放在线音频

### ❌ 没有在线音频 - 跳过播放

```dart
WordAudio(
  audioUrl: null,  // 没有在线音频
  audioFilename: 'word_123.mp3',  // ⚠️ 不会使用
)
```

**结果**: 抛出异常 `"没有可用的在线音频: word_123.mp3"`

## 播放流程

```
检查 audioUrl
  ├─ 存在 → 播放在线音频 ✅
  └─ 不存在 → 抛出异常 ❌
```

## 优势

1. **简化逻辑** - 不需要处理本地文件
2. **减少 APK 体积** - 不打包音频文件
3. **易于更新** - 音频更新无需发布新版本
4. **统一管理** - 所有音频集中在服务器

## 注意事项

1. **网络依赖** - 必须有网络连接才能播放音频
2. **数据流量** - 会消耗用户流量
3. **加载延迟** - 首次播放可能有网络延迟
4. **离线不可用** - 离线状态下无法播放

## 数据库要求

所有音频记录必须有有效的 `audio_url`：

```sql
-- ✅ 正确：有 audio_url
INSERT INTO word_audio (word_id, audio_filename, audio_url) 
VALUES (1, 'word.mp3', 'https://cdn.example.com/audio/word.mp3');

-- ❌ 错误：没有 audio_url（无法播放）
INSERT INTO word_audio (word_id, audio_filename, audio_url) 
VALUES (1, 'word.mp3', NULL);
```

## UI 处理建议

在 UI 中检查是否有可用音频：

```dart
// 检查是否有在线音频
final hasAudio = audio.audioUrl != null && audio.audioUrl!.isNotEmpty;

// 根据情况显示播放按钮
IconButton(
  icon: Icon(Icons.volume_up),
  onPressed: hasAudio ? () {
    controller.playWordAudio(audio);
  } : null,  // 没有音频时禁用按钮
  color: hasAudio ? Colors.blue : Colors.grey,
)
```

## 错误处理

```dart
try {
  await audioService.playWordAudio(audio);
} catch (e) {
  if (e.toString().contains('没有可用的在线音频')) {
    // 提示用户：此单词暂无音频
    showSnackBar('此单词暂无音频');
  } else {
    // 其他错误（网络问题等）
    showSnackBar('音频加载失败，请检查网络');
  }
}
```

## 日志示例

### 成功播放

```
[INFO] 播放在线音频: https://cdn.example.com/audio/word.mp3
[INFO] 在线音频播放成功
```

### 没有在线音频

```
[WARNING] 没有在线音频，跳过播放: word_123.mp3
```

### 网络错误

```
[INFO] 播放在线音频: https://cdn.example.com/audio/word.mp3
[ERROR] 在线音频加载失败: NetworkException
```

## 如何恢复本地音频支持

如果将来需要恢复本地音频支持，修改 `lib/services/audio_service.dart` 中的 `_playAudioWithFallback` 方法：

```dart
Future<void> _playAudioWithFallback({
  String? audioUrl,
  required String audioFilename,
  required bool isWordAudio,
}) async {
  if (_player.playing) {
    await _player.stop();
  }

  // 尝试在线音频
  if (audioUrl != null && audioUrl.isNotEmpty) {
    try {
      _currentAudioSource = audioUrl;
      await _player.setUrl(audioUrl);
      await _player.play();
      return;
    } catch (e) {
      logger.warning('在线音频失败，尝试本地: $e');
      // 继续尝试本地
    }
  }

  // 回退到本地音频
  final folder = isWordAudio ? 'words' : 'examples';
  final assetPath = 'assets/audio/$folder/$audioFilename';
  
  try {
    _currentAudioSource = assetPath;
    await _player.setAsset(assetPath);
    await _player.play();
  } catch (e) {
    throw Exception('音频加载失败');
  }
}
```

## 相关文件

- `lib/services/audio_service.dart` - 音频服务实现
- `lib/services/README.md` - 服务文档
- `AUDIO_ONLINE_ONLY.md` - 本文档

## 总结

当前 AudioService 配置为仅在线模式，简化了音频管理，但要求所有音频都必须有有效的 `audio_url`。这种模式适合音频资源集中管理在服务器的场景。
