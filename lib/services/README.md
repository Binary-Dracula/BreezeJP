# Services 服务层

## 概述

`lib/services` 当前主要承载全局音频播放与播放状态同步能力。最核心的两个入口是：

- `AudioService`：真正执行播放、暂停、停止、seek、速度和音量控制
- `AudioPlayController`：把 `just_audio` 的播放器状态同步成 UI 友好的 `AudioPlayStatus`

## 音频服务（AudioService）

### 当前能力

- 单一播放入口：`playAudio(String? source)`
- 同时支持远端 URL 和本地 asset 路径
- 重复播放同一音源时会从头重播
- 切换到新音源前会先停止当前播放
- 通过 Riverpod Provider 管理生命周期，释放 `AudioPlayer`

### Provider

```dart
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
```

### 基本用法

```dart
final audioService = ref.read(audioServiceProvider);
await audioService.playAudio(source);
```

常见来源：

```dart
// 远端 URL
await audioService.playAudio('https://example.com/audio/word.mp3');

// 本地 asset（当前项目的假名音频就是这种用法）
await audioService.playAudio('assets/audio/kana/a.mp3');
```

### 播放控制

```dart
await audioService.pause();
await audioService.stop();
await audioService.seek(const Duration(seconds: 5));
await audioService.setVolume(0.8);
await audioService.setSpeed(1.25);
```

### 在线音频请求头

远端 URL 播放时，`AudioService` 会：

- 先对 URL 做 `Uri.encodeFull`
- 始终带上 `X-Breeze-Token`
- 当 URL 以 `ApiEndpoints.baseUrl` 开头时，额外附带当前 Supabase session 的 `Authorization: Bearer <jwt>`

### 状态读取

`AudioService` 暴露以下只读状态：

- `player`：底层 `AudioPlayer`
- `currentState`：`AudioStateEnum.unplayed / playing / pause`
- `currentAudioSource`：当前音源字符串

## 音频播放控制器（AudioPlayController）

UI 层通常不要直接监听 `AudioService.currentState`，而是使用 `audioPlayControllerProvider`：

```dart
final status = ref.watch(audioPlayControllerProvider);
final controller = ref.read(audioPlayControllerProvider.notifier);

await controller.toggle(source);
```

控制器会把 `just_audio` 的 `loading / ready / completed / idle` 状态映射成：

- `AudioPlayState.idle`
- `AudioPlayState.loading`
- `AudioPlayState.playing`
- `AudioPlayState.error`

适合用于多个播放按钮共享同一套加载中 / 播放中 UI 状态。

## 常见使用模式

### 1. Controller 中调用播放

```dart
class MyController extends Notifier<MyState> {
  Future<void> play(String source) async {
    try {
      await ref.read(audioServiceProvider).playAudio(source);
    } catch (e) {
      state = state.copyWith(error: '播放失败');
    }
  }
}
```

### 2. 监听底层播放器事件

```dart
ref.read(audioServiceProvider).player.playerStateStream.listen((playerState) {
  if (playerState.processingState == ProcessingState.completed) {
    // 播放结束
  }
});
```

### 3. 页面离开时停止播放

```dart
@override
void dispose() {
  ref.read(audioServiceProvider).stop();
  super.dispose();
}
```

## 当前文档边界

以下说法都已经过期，不应再复制到代码里：

- `playWordAudio(...)` / `playExampleAudio(...)`
- `WordAudio` / `ExampleAudio` 是 `AudioService` 的直接输入
- “当前只支持在线音频，不支持本地 asset”
- `_playAudioWithFallback` 是现役实现

## 注意事项

1. `playAudio` 收到空字符串或 `null` 时会直接返回，不会播放。
2. 远端音频播放失败会抛异常，调用方需要自行 `try-catch` 并给 UI 反馈。
3. 同一时间只维护一个活跃播放源；切换新音频时旧音频会被停止。
4. 传给 `playAudio` 的本地资源路径必须是 `setAsset(...)` 可识别的 asset key。
