# Controller 快速参考

## 导入

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

## HomeController - 主页统计

```dart
// 使用
final state = ref.watch(homeControllerProvider);
final controller = ref.read(homeControllerProvider.notifier);

// 加载统计
controller.loadStatistics();

// 访问数据
state.totalWords                    // 总单词数
state.wordCountByLevel              // {'N5': 800, ...}
state.getCountForLevel('N5')        // 获取 N5 数量
```

## WordListController - 单词列表

```dart
// 使用
final state = ref.watch(wordListControllerProvider);
final controller = ref.read(wordListControllerProvider.notifier);

// 加载单词
controller.loadWordsByLevel('N5');           // 按等级
controller.loadAllWords(page: 0);            // 分页
controller.searchWords('学校');               // 搜索

// 访问数据
state.words                         // 单词列表
state.totalCount                    // 总数
state.currentLevel                  // 当前等级
```

## WordDetailController - 单词详情

```dart
// 使用
final state = ref.watch(wordDetailControllerProvider);
final controller = ref.read(wordDetailControllerProvider.notifier);

// 加载详情
controller.loadWordDetail(123);

// 访问数据
state.detail?.word.word             // 单词文本
state.detail?.primaryMeaning        // 主要释义
state.detail?.primaryAudioPath      // 音频路径
state.detail?.meanings              // 所有释义
state.detail?.examples              // 所有例句
```

## LearnController - 学习模式

```dart
// 使用
final state = ref.watch(learnControllerProvider);
final controller = ref.read(learnControllerProvider.notifier);

// 开始学习
controller.startRandomLearning(     // 随机模式
  jlptLevel: 'N5',
  count: 10,
);
controller.startSequentialLearning( // 顺序模式
  jlptLevel: 'N5',
  startIndex: 0,
  count: 10,
);

// 导航
controller.nextWord();              // 下一个
controller.previousWord();          // 上一个
controller.goToWord(5);             // 跳转
controller.restart();               // 重新开始

// 访问数据
state.currentWord                   // 当前单词
state.progress                      // 进度 (0.0-1.0)
state.hasNext                       // 是否有下一个
state.hasPrevious                   // 是否有上一个
state.isCompleted                   // 是否完成
```

## 在 UI 中使用

### ConsumerWidget

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);
    final controller = ref.read(myControllerProvider.notifier);
    
    return Column(
      children: [
        if (state.isLoading) CircularProgressIndicator(),
        if (state.hasError) Text(state.error!),
        if (state.hasData) Text(state.data),
      ],
    );
  }
}
```

### 监听状态变化

```dart
ref.listen(myControllerProvider, (previous, next) {
  if (next.hasError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next.error!)),
    );
  }
});
```

### 初始化加载

```dart
class MyPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myControllerProvider.notifier).loadData();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myControllerProvider);
    return Text(state.data);
  }
}
```

## 常用模式

### 加载-错误-数据

```dart
if (state.isLoading) {
  return CircularProgressIndicator();
}

if (state.hasError) {
  return ErrorWidget(state.error!);
}

if (!state.hasData) {
  return Text('暂无数据');
}

return DataWidget(state.data);
```

### 下拉刷新

```dart
RefreshIndicator(
  onRefresh: () async {
    await ref.read(myControllerProvider.notifier).refresh();
  },
  child: ListView(...),
)
```

## 所有 Controller

| Controller | Provider | 功能 |
|-----------|----------|------|
| HomeController | `homeControllerProvider` | 主页统计 |
| WordListController | `wordListControllerProvider` | 单词列表 |
| WordDetailController | `wordDetailControllerProvider` | 单词详情 |
| LearnController | `learnControllerProvider` | 学习模式 |
| SplashController | `splashControllerProvider` | 启动初始化 |
