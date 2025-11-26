# Design Document

## Overview

本设计文档描述了 BreezeJP 学习页面水平滑动导航功能的技术实现方案。该功能将现有的垂直列表布局重构为基于 PageView 的水平翻页体验，实现沉浸式的单词学习流程。

核心设计目标：
- 使用 PageView.builder 实现水平滑动切换单词
- 每个单词页面内部使用 SingleChildScrollView 支持垂直滚动查看详情
- 实现预加载机制，在用户学习到倒数第 5 个单词时自动加载下一批
- 自动标记学习状态并记录学习日志
- 记录和更新每日学习统计数据

## Architecture

### MVVM 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│ View Layer (UI)                                              │
│ - LearnPage: 主学习页面，负责渲染和用户交互                    │
│ - WordDetailPage: 单词详情页面，负责单个单词的展示             │
│ - WordCard: 单词卡片组件                                      │
│ - ExampleCard: 例句卡片组件                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓ ref.watch / ref.read
┌─────────────────────────────────────────────────────────────┐
│ ViewModel Layer (Controller + State)                        │
│ - LearnController: 业务逻辑控制器                             │
│   * loadWords(): 加载单词                                     │
│   * onPageChanged(): 处理页面切换                             │
│   * markWordAsLearned(): 标记学习状态                         │
│   * checkAndPreload(): 检查并预加载                           │
│   * updateDailyStats(): 更新统计                              │
│ - LearnState: 不可变状态模型                                  │
│   * studyQueue: 学习队列                                      │
│   * currentIndex: 当前索引                                    │
│   * learnedWordIds: 已学习单词集合                            │
└─────────────────────────────────────────────────────────────┘
                            ↓ 调用
┌─────────────────────────────────────────────────────────────┐
│ Repository Layer (数据访问)                                  │
│ - WordRepository: 单词数据访问                                │
│   * getWordDetail(): 获取单词详情                             │
│   * getUnlearnedWords(): 获取未学习单词                       │
│ - StudyWordRepository: 学习状态数据访问                       │
│   * markAsLearned(): 标记为已学习                             │
│ - StudyLogRepository: 学习日志数据访问                        │
│   * insertLog(): 插入学习日志                                 │
│ - DailyStatRepository: 每日统计数据访问                       │
│   * updateDailyStats(): 更新每日统计                          │
└─────────────────────────────────────────────────────────────┘
                            ↓ 操作
┌─────────────────────────────────────────────────────────────┐
│ Data Layer (数据源)                                          │
│ - AppDatabase: SQLite 数据库单例                             │
│ - Models: 数据模型 (Word, WordDetail, StudyWord, etc.)       │
└─────────────────────────────────────────────────────────────┘
```

### 组件层次结构

```
LearnPage (View - StatefulWidget)
├── AppBar (显示序号)
├── PageView.builder (水平滑动)
│   └── itemBuilder 返回:
│       └── SingleChildScrollView (垂直滚动)
│           └── Column
│               ├── WordCard (View - StatelessWidget)
│               └── ExampleCard[] (View - StatelessWidget)
└── FinishedScreen (View - 完成界面)
```

### 状态管理

使用 Riverpod 的 NotifierProvider 管理学习状态：

```dart
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new
);
```

### 数据流（严格单向）

```
用户交互 (View)
    ↓
LearnController (ViewModel)
    ↓
Repository (Data Access)
    ↓
Database (Data Source)
    ↓
Model (Data)
    ↓
State Update (ViewModel)
    ↓
UI Rebuild (View)
```

### 职责分离原则

**View Layer (UI)**
- ✅ 只负责渲染 UI 和接收用户输入
- ✅ 通过 ref.watch 监听状态变化
- ✅ 通过 ref.read 调用 Controller 方法
- ❌ 不直接访问 Repository
- ❌ 不包含业务逻辑
- ❌ 不直接操作数据库

**ViewModel Layer (Controller + State)**
- ✅ 包含所有业务逻辑
- ✅ 管理应用状态
- ✅ 调用 Repository 获取/更新数据
- ✅ 将数据转换为 UI 需要的格式
- ❌ 不直接操作数据库
- ❌ 不包含 UI 代码

**Repository Layer**
- ✅ 封装所有数据库操作
- ✅ 返回 Model 对象
- ✅ 提供 CRUD 接口
- ❌ 不包含业务逻辑
- ❌ 不知道 UI 的存在

**Data Layer**
- ✅ 提供数据源访问
- ✅ 定义数据模型
- ❌ 不包含业务逻辑

## Components and Interfaces

### 1. LearnPage (UI 组件)

主学习页面组件，负责渲染 PageView 和处理用户交互。

```dart
class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});
}

class _LearnPageState extends ConsumerState<LearnPage> {
  late PageController _pageController;
  DateTime? _sessionStartTime;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _sessionStartTime = DateTime.now();
    // 加载初始单词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(learnControllerProvider.notifier).loadWords(
        count: AppConstants.defaultLearnCount,
      );
    });
  }
  
  @override
  void dispose() {
    // 保存学习统计数据
    _saveDailyStats();
    _pageController.dispose();
    super.dispose();
  }
  
  void _saveDailyStats() {
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      ref.read(learnControllerProvider.notifier).updateDailyStats(
        durationMs: duration.inMilliseconds,
      );
    }
  }
}
```

### 2. LearnController (业务逻辑)

管理学习流程的核心控制器。

```dart
class LearnController extends Notifier<LearnState> {
  @override
  LearnState build() => const LearnState();
  
  // 加载单词
  Future<void> loadWords({int count = 20}) async;
  
  // 页面切换回调
  Future<void> onPageChanged(int newIndex) async;
  
  // 标记单词为已学习
  Future<void> markWordAsLearned(int wordId) async;
  
  // 检查并触发预加载
  Future<void> checkAndPreload() async;
  
  // 更新每日统计
  Future<void> updateDailyStats({required int durationMs}) async;
  
  // 结束学习会话
  Future<void> endSession() async;
}
```

### 3. LearnState (状态模型)

```dart
@freezed
class LearnState with _$LearnState {
  const factory LearnState({
    @Default([]) List<WordDetail> studyQueue,
    @Default(0) int currentIndex,
    @Default(false) bool isLoading,
    @Default(false) bool isPreloading,
    @Default(false) bool hasMoreWords,
    @Default({}) Set<int> learnedWordIds,
    String? error,
  }) = _LearnState;
}

extension LearnStateX on LearnState {
  WordDetail? get currentWordDetail => 
    currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;
  
  bool get isBatchCompleted => 
    !hasMoreWords && currentIndex >= studyQueue.length;
}
```

### 4. WordRepository (数据访问)

扩展现有的 WordRepository，添加预加载相关方法。

```dart
class WordRepository {
  // 现有方法...
  
  // 获取未学习的单词（排除已学习的）
  Future<List<Word>> getUnlearnedWords({
    int limit = 20,
    List<int> excludeIds = const [],
  }) async {
    final db = await AppDatabase.instance.database;
    
    String whereClause = 'id NOT IN (SELECT word_id FROM study_words WHERE user_state > 0)';
    
    if (excludeIds.isNotEmpty) {
      whereClause += ' AND id NOT IN (${excludeIds.join(',')})';
    }
    
    final results = await db.query(
      'words',
      where: whereClause,
      limit: limit,
    );
    
    return results.map((map) => Word.fromMap(map)).toList();
  }
}
```

### 5. StudyWordRepository (学习状态管理)

```dart
class StudyWordRepository {
  // 标记单词为已学习
  Future<void> markAsLearned({
    required int userId,
    required int wordId,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await db.insert(
      'study_words',
      {
        'user_id': userId,
        'word_id': wordId,
        'user_state': 1, // 学习中
        'last_reviewed_at': now,
        'total_reviews': 1,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

### 6. StudyLogRepository (学习日志)

```dart
class StudyLogRepository {
  // 插入学习日志
  Future<void> insertLog({
    required int userId,
    required int wordId,
    required int logType, // 1=初学
    int? durationMs,
  }) async {
    final db = await AppDatabase.instance.database;
    
    await db.insert('study_logs', {
      'user_id': userId,
      'word_id': wordId,
      'log_type': logType,
      'duration_ms': durationMs ?? 0,
    });
  }
}
```

### 7. DailyStatRepository (每日统计)

```dart
class DailyStatRepository {
  // 更新每日统计
  Future<void> updateDailyStats({
    required int userId,
    required int learnedCount,
    required int durationMs,
  }) async {
    final db = await AppDatabase.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 尝试获取今天的记录
    final existing = await db.query(
      'daily_stats',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
    );
    
    if (existing.isEmpty) {
      // 创建新记录
      await db.insert('daily_stats', {
        'user_id': userId,
        'date': today,
        'total_study_time_ms': durationMs,
        'learned_words_count': learnedCount,
      });
    } else {
      // 累加更新
      await db.update(
        'daily_stats',
        {
          'total_study_time_ms': existing.first['total_study_time_ms'] as int + durationMs,
          'learned_words_count': existing.first['learned_words_count'] as int + learnedCount,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
      );
    }
  }
}
```

## Data Models

### LearnState 扩展

现有的 LearnState 需要添加以下字段：

```dart
@freezed
class LearnState with _$LearnState {
  const factory LearnState({
    @Default([]) List<WordDetail> studyQueue,
    @Default(0) int currentIndex,
    @Default(false) bool isLoading,
    @Default(false) bool isPreloading,  // 新增：是否正在预加载
    @Default(true) bool hasMoreWords,   // 新增：是否还有更多单词
    @Default({}) Set<int> learnedWordIds, // 新增：已学习的单词 ID 集合
    String? error,
    // 保留现有字段...
  }) = _LearnState;
}
```

### AppConstants 扩展

在 `lib/core/constants/app_constants.dart` 中添加预加载阈值常量：

```dart
class AppConstants {
  // 现有常量...
  
  /// 预加载阈值：当剩余单词数小于等于此值时触发预加载
  static const int preloadThreshold = 5;
  
  /// 默认每次学习的单词数量
  static const int defaultLearnCount = 20;
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 向左滑动递增索引

*For any* 学习队列和当前索引（不是最后一个），向左滑动应该使索引递增 1，并显示下一个单词的内容。

**Validates: Requirements 1.1**

### Property 2: 向右滑动递减索引

*For any* 学习队列和当前索引（不是第一个），向右滑动应该使索引递减 1，并显示上一个单词的内容。

**Validates: Requirements 1.2**

### Property 3: 序号显示正确性

*For any* 学习队列和当前索引，显示的序号应该等于当前索引加 1。

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 4: 滑动自动标记学习状态

*For any* 单词，当用户滑动离开该单词时，该单词应该被添加到已学习集合中。

**Validates: Requirements 4.1**

### Property 5: 标记学习状态更新数据库

*For any* 单词，当该单词被标记为已学习时，study_words 表中应该有对应的记录，且 user_state 为 1。

**Validates: Requirements 4.2**

### Property 6: 标记学习状态插入日志

*For any* 单词，当该单词被标记为已学习时，study_logs 表中应该有对应的日志记录，且 log_type 为 1。

**Validates: Requirements 4.3**

### Property 7: 不重复标记已学习单词

*For any* 单词，如果该单词已经在已学习集合中，再次滑动离开时不应该重复标记。

**Validates: Requirements 4.4**

### Property 8: 标记失败不中断流程

*For any* 单词，当标记学习状态失败时，应该记录错误但不抛出异常，用户可以继续学习。

**Validates: Requirements 4.5**

### Property 9: 预加载触发条件

*For any* 学习队列，当当前索引到达队列长度减去预加载阈值（5）时，应该触发预加载。

**Validates: Requirements 5.1**

### Property 10: 预加载追加单词

*For any* 学习队列，当预加载完成时，新单词应该被追加到队列末尾，队列长度应该增加。

**Validates: Requirements 5.2**

### Property 11: 预加载失败不影响学习

*For any* 学习队列，当预加载失败时，应该记录错误但不影响当前学习流程，用户可以继续学习现有单词。

**Validates: Requirements 5.3**

### Property 12: 防止重复预加载

*For any* 学习队列，当队列中已有足够单词时（剩余单词数大于预加载阈值），不应该触发重复预加载。

**Validates: Requirements 5.6**

### Property 13: 记录学习开始时间

*For any* 学习会话，当用户进入学习页面时，应该记录当前时间作为开始时间。

**Validates: Requirements 6.1**

### Property 14: 计算学习时长

*For any* 学习会话，当用户离开学习页面时，应该计算开始时间和结束时间的差值作为学习时长。

**Validates: Requirements 6.2**

### Property 15: 更新每日统计

*For any* 学习会话，当用户离开学习页面时，应该更新 daily_stats 表中的学习时长和已学单词数。

**Validates: Requirements 6.3, 6.4**

### Property 16: 累加更新每日统计

*For any* 学习会话，当当天已有学习记录时，应该累加更新学习时长和已学单词数，而不是覆盖。

**Validates: Requirements 6.6**

### Property 17: 保存统计数据

*For any* 学习会话，当用户返回首页时，应该保存本次学习的统计数据到数据库。

**Validates: Requirements 7.3**

## Error Handling

暂不处理异常情况，假设所有数据库操作都会成功。这样可以简化实现，专注于核心功能。

未来可以添加的错误处理：
- 数据库操作失败的 try-catch
- 预加载失败的重试机制
- 空队列的友好提示
- 页面切换异常的捕获

## Testing Strategy

### Unit Testing

使用 Flutter 的 test 包进行单元测试，重点测试：

1. **LearnController 业务逻辑**
   - 测试 loadWords 方法是否正确加载单词
   - 测试 onPageChanged 方法是否正确更新索引和标记学习状态
   - 测试 checkAndPreload 方法是否在正确时机触发预加载
   - 测试 updateDailyStats 方法是否正确更新统计数据

2. **Repository 数据访问**
   - 测试 getUnlearnedWords 方法是否正确过滤已学习单词
   - 测试 markAsLearned 方法是否正确更新数据库
   - 测试 insertLog 方法是否正确插入日志
   - 测试 updateDailyStats 方法是否正确处理首次和累加更新

3. **LearnState 扩展方法**
   - 测试 currentWordDetail getter 是否返回正确的单词
   - 测试 isBatchCompleted getter 是否正确判断完成状态

### Property-Based Testing

使用 Dart 的 `test` 包和 `faker` 包进行属性测试，配置每个测试运行至少 100 次迭代。

每个属性测试必须使用注释标记对应的设计文档中的属性编号：

```dart
// Feature: horizontal-word-navigation, Property 1: 向左滑动递增索引
test('property: swipe left increments index', () {
  // 测试代码
});
```

重点测试的属性：

1. **Property 1-2**: 滑动切换索引的正确性
2. **Property 3**: 序号显示的正确性
3. **Property 4-8**: 学习状态标记的正确性和幂等性
4. **Property 9-12**: 预加载机制的正确性
5. **Property 13-17**: 统计数据记录的正确性

### Integration Testing

暂不实现集成测试，专注于单元测试和属性测试。

## Implementation Notes

### 模块化原则

**1. View 层实现规范**
```dart
// ✅ 正确：View 只负责 UI 渲染和用户交互
class LearnPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  late PageController _pageController;
  DateTime? _sessionStartTime;
  
  @override
  Widget build(BuildContext context) {
    // 监听状态
    final state = ref.watch(learnControllerProvider);
    
    // 渲染 UI
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // 触觉反馈在 View 层处理（UI 相关）
          HapticFeedback.lightImpact();
          // 业务逻辑委托给 Controller
          ref.read(learnControllerProvider.notifier).onPageChanged(index);
        },
        itemBuilder: (context, index) {
          final wordDetail = state.studyQueue[index];
          final controller = ref.read(learnControllerProvider.notifier);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                WordCard(
                  wordDetail: wordDetail,
                  isPlayingAudio: state.isPlayingWordAudio,
                  onPlayAudio: controller.playWordAudio,
                ),
                const SizedBox(height: 24),
                ...wordDetail.examples.asMap().entries.map((entry) {
                  return ExampleCard(
                    example: entry.value,
                    index: entry.key,
                    isPlaying: state.isPlayingExampleAudio && 
                              state.playingExampleIndex == entry.key,
                    onPlayAudio: () => controller.playExampleAudio(entry.key),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ❌ 错误：View 不应该包含业务逻辑
class _LearnPageState extends ConsumerState<LearnPage> {
  void _onPageChanged(int index) {
    // ❌ 不要在 View 中写业务逻辑
    if (index > currentIndex) {
      // 标记单词...
      // 检查预加载...
    }
  }
}
```

**2. ViewModel 层实现规范**
```dart
// ✅ 正确：Controller 只包含业务逻辑
class LearnController extends Notifier<LearnState> {
  // 依赖注入 Repository
  late final WordRepository _wordRepository;
  late final StudyWordRepository _studyWordRepository;
  late final StudyLogRepository _studyLogRepository;
  late final DailyStatRepository _dailyStatRepository;
  
  @override
  LearnState build() {
    // 初始化 Repository
    _wordRepository = ref.read(wordRepositoryProvider);
    _studyWordRepository = ref.read(studyWordRepositoryProvider);
    _studyLogRepository = ref.read(studyLogRepositoryProvider);
    _dailyStatRepository = ref.read(dailyStatRepositoryProvider);
    
    return const LearnState();
  }
  
  // 业务逻辑方法
  Future<void> onPageChanged(int newIndex) async {
    // 标记学习状态
    if (newIndex > state.currentIndex && state.currentIndex < state.studyQueue.length) {
      final previousWordId = state.studyQueue[state.currentIndex].word.id;
      if (!state.learnedWordIds.contains(previousWordId)) {
        await markWordAsLearned(previousWordId);
      }
    }
    
    // 更新状态
    state = state.copyWith(currentIndex: newIndex);
    
    // 检查预加载
    await checkAndPreload();
  }
  
  // ❌ 不要在 Controller 中直接操作数据库
  // Future<void> markWordAsLearned(int wordId) async {
  //   final db = await AppDatabase.instance.database;
  //   await db.insert('study_words', {...});
  // }
  
  // ✅ 正确：通过 Repository 操作数据
  Future<void> markWordAsLearned(int wordId) async {
    state = state.copyWith(
      learnedWordIds: {...state.learnedWordIds, wordId},
    );
    
    await _studyWordRepository.markAsLearned(userId: 1, wordId: wordId);
    await _studyLogRepository.insertLog(userId: 1, wordId: wordId, logType: 1);
  }
}
```

**3. Repository 层实现规范**
```dart
// ✅ 正确：Repository 只负责数据访问
class WordRepository {
  Future<List<Word>> getUnlearnedWords({
    int limit = 20,
    List<int> excludeIds = const [],
  }) async {
    final db = await AppDatabase.instance.database;
    
    String whereClause = 'id NOT IN (SELECT word_id FROM study_words WHERE user_state > 0)';
    if (excludeIds.isNotEmpty) {
      whereClause += ' AND id NOT IN (${excludeIds.join(',')})';
    }
    
    final results = await db.query('words', where: whereClause, limit: limit);
    return results.map((map) => Word.fromMap(map)).toList();
  }
  
  // ❌ 不要在 Repository 中包含业务逻辑
  // Future<List<Word>> getWordsForLearning() async {
  //   final words = await getUnlearnedWords();
  //   // ❌ 不要在这里做业务判断
  //   if (words.length < 5) {
  //     // 触发预加载...
  //   }
  //   return words;
  // }
}
```

### 关键实现细节

**1. PageView 配置**
```dart
PageView.builder(
  controller: _pageController,
  onPageChanged: (index) {
    HapticFeedback.lightImpact();
    ref.read(learnControllerProvider.notifier).onPageChanged(index);
  },
  itemCount: state.studyQueue.length,
  itemBuilder: (context, index) {
    final wordDetail = state.studyQueue[index];
    final controller = ref.read(learnControllerProvider.notifier);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 单词卡片
          WordCard(
            wordDetail: wordDetail,
            isPlayingAudio: state.isPlayingWordAudio,
            onPlayAudio: controller.playWordAudio,
          ),
          const SizedBox(height: 24),
          
          // 例句列表
          ...wordDetail.examples.asMap().entries.map((entry) {
            final idx = entry.key;
            final example = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ExampleCard(
                example: example,
                index: idx,
                isPlaying: state.isPlayingExampleAudio && 
                          state.playingExampleIndex == idx,
                onPlayAudio: () => controller.playExampleAudio(idx),
              ),
            );
          }),
        ],
      ),
    );
  },
)
```

**2. 防止重复标记**
```dart
if (!state.learnedWordIds.contains(wordId)) {
  await markWordAsLearned(wordId);
}
```

**3. 完成界面判断**
```dart
bool get isBatchCompleted => 
  !hasMoreWords && currentIndex >= studyQueue.length;
```

**4. 每日统计更新**
```dart
@override
void dispose() {
  if (_sessionStartTime != null) {
    final duration = DateTime.now().difference(_sessionStartTime!);
    final learnedCount = ref.read(learnControllerProvider).learnedWordIds.length;
    
    ref.read(learnControllerProvider.notifier).updateDailyStats(
      durationMs: duration.inMilliseconds,
      learnedCount: learnedCount,
    );
  }
  _pageController.dispose();
  super.dispose();
}
```

**5. 常量定义**
```dart
class AppConstants {
  /// 预加载阈值：当剩余单词数小于等于此值时触发预加载
  static const int preloadThreshold = 5;
  
  /// 默认每次学习的单词数量
  static const int defaultLearnCount = 20;
}
```

## Performance Considerations

1. **预加载优化**: 使用 Future.wait 并行加载多个单词的详情，减少加载时间
2. **内存管理**: 只保留当前批次的单词在内存中，避免加载过多数据
3. **数据库批量操作**: 考虑使用批量插入优化日志记录性能
4. **状态更新**: 使用 copyWith 而不是直接修改状态，保持不可变性

## Migration Path

从现有的垂直列表布局迁移到水平滑动布局：

1. **保留现有组件**: WordCard 和 ExampleCard 组件保持不变
2. **替换布局**: 将 ListView 替换为 PageView.builder
3. **移除底部按钮**: 删除"下一个"和"完成"按钮相关代码
4. **添加预加载逻辑**: 在 LearnController 中添加预加载相关方法
5. **更新状态管理**: 扩展 LearnState 添加新字段
6. **添加统计记录**: 在页面生命周期中添加统计数据记录

## Dependencies

- `flutter/services.dart`: 用于触觉反馈 (HapticFeedback)
- `intl`: 用于日期格式化 (DateFormat)
- 现有依赖保持不变

## Future Enhancements

1. **动画效果**: 添加页面切换动画和卡片加载动画
2. **手势优化**: 支持快速滑动跳过多个单词
3. **离线缓存**: 预加载时缓存音频文件
4. **学习进度可视化**: 在顶部添加进度条显示整体学习进度
5. **自定义预加载阈值**: 允许用户在设置中调整预加载时机
