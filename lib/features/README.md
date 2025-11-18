# Features 层

功能模块层，每个功能模块包含 Controller、State、Pages 和 Widgets。

## 已实现的功能模块

### 1. Home - 主页
**路径**: `lib/features/home/`

**功能**: 显示应用统计信息和导航入口

**文件**:
- `controller/home_controller.dart` - 主页控制器
- `state/home_state.dart` - 主页状态
- `pages/home_page.dart` - 主页 UI

**State**:
```dart
class HomeState {
  final bool isLoading;
  final Map<String, int> wordCountByLevel;  // 各等级单词数量
  final int totalWords;                      // 总单词数
  final String? error;
}
```

**使用示例**:
```dart
// 在 UI 中使用
class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    
    // 加载统计信息
    ref.read(homeControllerProvider.notifier).loadStatistics();
    
    return Column(
      children: [
        Text('总单词数: ${state.totalWords}'),
        Text('N5: ${state.getCountForLevel('N5')}'),
        Text('N4: ${state.getCountForLevel('N4')}'),
      ],
    );
  }
}
```

---

### 2. WordList - 单词列表
**路径**: `lib/features/word_list/`

**功能**: 显示和搜索单词列表

**文件**:
- `controller/word_list_controller.dart` - 列表控制器
- `state/word_list_state.dart` - 列表状态

**State**:
```dart
class WordListState {
  final bool isLoading;
  final List<Word> words;           // 单词列表
  final String? error;
  final String? currentLevel;       // 当前等级
  final int totalCount;             // 总数
}
```

**使用示例**:
```dart
class WordListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wordListControllerProvider);
    final controller = ref.read(wordListControllerProvider.notifier);
    
    // 加载 N5 单词
    controller.loadWordsByLevel('N5');
    
    // 搜索单词
    controller.searchWords('学校');
    
    return ListView.builder(
      itemCount: state.words.length,
      itemBuilder: (context, index) {
        final word = state.words[index];
        return ListTile(
          title: Text(word.word),
          subtitle: Text(word.furigana ?? ''),
        );
      },
    );
  }
}
```

---

### 3. WordDetail - 单词详情
**路径**: `lib/features/word_detail/`

**功能**: 显示单词的完整信息（释义、音频、例句）

**文件**:
- `controller/word_detail_controller.dart` - 详情控制器
- `state/word_detail_state.dart` - 详情状态

**State**:
```dart
class WordDetailState {
  final bool isLoading;
  final WordDetail? detail;  // 单词完整详情
  final String? error;
  final int? wordId;
}
```

**使用示例**:
```dart
class WordDetailPage extends ConsumerWidget {
  final int wordId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wordDetailControllerProvider);
    final controller = ref.read(wordDetailControllerProvider.notifier);
    
    // 加载单词详情
    controller.loadWordDetail(wordId);
    
    if (state.detail == null) return CircularProgressIndicator();
    
    final detail = state.detail!;
    return Column(
      children: [
        Text(detail.word.word),
        Text(detail.primaryMeaning ?? ''),
        // 显示例句
        ...detail.examples.map((e) => Text(e.sentence.sentenceJp)),
      ],
    );
  }
}
```

---

### 4. Learn - 学习功能
**路径**: `lib/features/learn/`

**功能**: 单词学习模式（随机/顺序）

**文件**:
- `controller/learn_controller.dart` - 学习控制器
- `state/learn_state.dart` - 学习状态

**State**:
```dart
class LearnState {
  final bool isLoading;
  final List<WordDetail> words;     // 学习单词列表
  final int currentIndex;           // 当前索引
  final String? error;
  final String? jlptLevel;
  final int totalWords;
  final bool isCompleted;           // 是否完成
  
  // 便捷方法
  WordDetail? get currentWord;      // 当前单词
  bool get hasNext;                 // 是否有下一个
  bool get hasPrevious;             // 是否有上一个
  double get progress;              // 进度百分比
}
```

**使用示例**:
```dart
class LearnPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learnControllerProvider);
    final controller = ref.read(learnControllerProvider.notifier);
    
    // 开始随机学习
    controller.startRandomLearning(
      jlptLevel: 'N5',
      count: 10,
    );
    
    // 导航
    controller.nextWord();      // 下一个
    controller.previousWord();  // 上一个
    controller.restart();       // 重新开始
    
    final currentWord = state.currentWord;
    if (currentWord == null) return CircularProgressIndicator();
    
    return Column(
      children: [
        Text('进度: ${(state.progress * 100).toInt()}%'),
        Text(currentWord.word.word),
        Text(currentWord.primaryMeaning ?? ''),
        Row(
          children: [
            if (state.hasPrevious)
              ElevatedButton(
                onPressed: controller.previousWord,
                child: Text('上一个'),
              ),
            if (state.hasNext)
              ElevatedButton(
                onPressed: controller.nextWord,
                child: Text('下一个'),
              ),
          ],
        ),
      ],
    );
  }
}
```

---

### 5. Splash - 启动页
**路径**: `lib/features/splash/`

**功能**: 应用启动和初始化

**文件**:
- `controller/splash_controller.dart` - 启动控制器
- `state/splash_state.dart` - 启动状态
- `pages/splash_page.dart` - 启动页 UI

**已实现**: ✅

---

## Controller 使用模式

### 1. 在 UI 中使用

```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听状态
    final state = ref.watch(myControllerProvider);
    
    // 获取控制器
    final controller = ref.read(myControllerProvider.notifier);
    
    // 调用方法
    controller.loadData();
    
    return Text(state.data);
  }
}
```

### 2. 监听状态变化

```dart
ref.listen(myControllerProvider, (previous, next) {
  if (next.hasError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next.error!)),
    );
  }
});
```

### 3. 在 initState 中调用

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

## State 设计原则

### 1. 不可变性
所有 State 类都是不可变的，使用 `copyWith` 方法更新。

```dart
class MyState {
  final bool isLoading;
  final String? data;
  
  const MyState({this.isLoading = false, this.data});
  
  MyState copyWith({bool? isLoading, String? data}) {
    return MyState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
    );
  }
}
```

### 2. 便捷方法
提供便捷的访问方法。

```dart
class MyState {
  final List<Item> items;
  
  bool get hasData => items.isNotEmpty;
  bool get isEmpty => items.isEmpty;
  int get count => items.length;
}
```

### 3. 错误处理
统一的错误字段。

```dart
class MyState {
  final String? error;
  
  bool get hasError => error != null;
}
```

## Controller 设计原则

### 1. 单一职责
每个 Controller 只负责一个功能模块。

### 2. 日志记录
所有重要操作都记录日志。

```dart
Future<void> loadData() async {
  logger.info('开始加载数据');
  try {
    // 加载逻辑
    logger.info('数据加载成功');
  } catch (e, stackTrace) {
    logger.error('加载失败', e, stackTrace);
  }
}
```

### 3. 错误处理
统一的错误处理模式。

```dart
try {
  // 操作
} catch (e, stackTrace) {
  logger.error('操作失败', e, stackTrace);
  state = state.copyWith(error: '操作失败: $e');
}
```

### 4. 清理方法
提供清理和重置方法。

```dart
void clear() {
  state = const MyState();
}

void clearError() {
  state = state.copyWith(error: null);
}
```

## 最佳实践

### ✅ 推荐做法

1. **使用 Provider 注入依赖**
   ```dart
   final myRepositoryProvider = Provider((ref) => MyRepository());
   
   class MyController extends Notifier<MyState> {
     MyRepository get _repository => ref.read(myRepositoryProvider);
   }
   ```

2. **状态更新使用 copyWith**
   ```dart
   state = state.copyWith(isLoading: true);
   ```

3. **记录日志**
   ```dart
   logger.info('操作开始');
   logger.error('操作失败', e, stackTrace);
   ```

4. **提供便捷方法**
   ```dart
   void refresh() => loadData();
   void clearError() => state = state.copyWith(error: null);
   ```

### ❌ 避免做法

1. ❌ 直接修改 state 的属性
2. ❌ 在 Controller 中处理 UI 逻辑
3. ❌ 忽略错误处理
4. ❌ 不记录日志

## 待实现的功能模块

- `Review` - 复习功能
- `Settings` - 设置功能
- `Search` - 搜索功能（独立）
- `Statistics` - 统计功能（独立）

---

Controller 层提供了清晰的业务逻辑封装，使 UI 层保持简洁。
