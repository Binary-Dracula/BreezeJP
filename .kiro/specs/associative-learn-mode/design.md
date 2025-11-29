# Design Document

## Overview

本设计文档描述了 BreezeJP 语义分支学习模式（Associative Learn Mode）的技术实现方案。该功能实现无尽探索式的单词学习体验，核心理念是通过关联词链条让用户在语义网络中自然记忆单词。

核心设计目标：
- 初始选择页展示 5 个随机单词作为学习起点
- 学习页面使用 PageView 实现左右滑动切换单词
- 每个单词页面内部使用 SingleChildScrollView 支持上下滚动查看详情
- 基于 word_relations 表实现关联词加载和无尽探索
- 音频播放按钮状态与 AudioService.currentState 同步
- 自动标记学习状态并记录学习日志

## Architecture

### MVVM 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│ View Layer (UI)                                              │
│                                                              │
│ 【初始选择页】                                                │
│ - InitialChoicePage: 独立页面，展示 5 个随机单词起点          │
│ - WordChoiceCard: 单词选择卡片组件                            │
│                                                              │
│ 【学习页】                                                    │
│ - LearnPage: 独立页面，全屏展示单词详情                       │
│ - WordCard: 单词卡片组件                                      │
│ - ExampleCard: 例句卡片组件                                   │
│ - AudioPlayButton: 音频播放按钮组件                           │
└─────────────────────────────────────────────────────────────┘
                            ↓ ref.watch / ref.read
┌─────────────────────────────────────────────────────────────┐
│ ViewModel Layer (Controller + State)                        │
│                                                              │
│ 【初始选择页】                                                │
│ - InitialChoiceController: 初始选择页控制器                   │
│   * loadChoices(): 加载 5 个随机单词                          │
│   * refresh(): 刷新选择                                       │
│ - InitialChoiceState: 初始选择页状态                          │
│   * choices: 5 个单词选择项                                   │
│                                                              │
│ 【学习页】                                                    │
│ - LearnController: 学习页控制器                               │
│   * initWithWord(): 初始化学习（传入选中的单词 ID）           │
│   * onPageChanged(): 处理页面切换                             │
│   * loadRelatedWords(): 加载关联词                            │
│   * markWordAsLearned(): 标记学习状态                         │
│   * playAudio(): 播放音频                                     │
│   * updateDailyStats(): 更新统计                              │
│ - LearnState: 学习页状态                                      │
│   * studyQueue: 学习队列                                      │
│   * currentIndex: 当前索引                                    │
│   * learnedWordIds: 已学习单词集合                            │
│   * pathEnded: 路径是否结束                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓ 调用
┌─────────────────────────────────────────────────────────────┐
│ Repository Layer (数据访问)                                  │
│ - WordRepository: 单词数据访问                                │
│   * getWordDetail(): 获取单词详情                             │
│   * getRandomUnmasteredWordsWithMeaning(): 获取随机未掌握单词 │
│   * getRelatedWords(): 获取关联词                             │
│ - StudyWordRepository: 学习状态数据访问                       │
│   * markAsLearned(): 标记为学习中                             │
│ - StudyLogRepository: 学习日志数据访问                        │
│   * insertLog(): 插入学习日志                                 │
│ - DailyStatRepository: 每日统计数据访问                       │
│   * updateDailyStats(): 更新每日统计                          │
└─────────────────────────────────────────────────────────────┘
                            ↓ 操作
┌─────────────────────────────────────────────────────────────┐
│ Data Layer (数据源)                                          │
│ - AppDatabase: SQLite 数据库单例                             │
│ - Models: Word, WordChoice, WordDetail, WordRelation, etc.   │
└─────────────────────────────────────────────────────────────┘
```

### 组件层次结构

**页面独立分离设计（沉浸式）：**

```
InitialChoicePage (独立页面 - 沉浸式设计)
├── Scaffold (无 AppBar，背景色统一)
│   └── SafeArea
│       └── Column
│           ├── 顶部操作栏 (透明背景，与页面融为一体)
│           │   ├── 返回按钮 (左)
│           │   └── 刷新按钮 (右)
│           ├── 标题区域 (页面内标题，非顶部栏)
│           └── GridView (5 个单词卡片)
│               └── WordChoiceCard

LearnPage (独立页面 - 沉浸式设计)
├── Scaffold (无 AppBar，背景色统一)
│   └── SafeArea
│       └── Column
│           ├── 顶部操作栏 (固定高度，不遮挡内容)
│           │   ├── 关闭按钮 (左)
│           │   └── 已学计数 "+N" (右)
│           └── Expanded
│               └── PageView.builder (水平滑动切换单词)
│                   └── SingleChildScrollView (垂直滚动查看详情)
│                       └── Column
│                           ├── WordCard
│                           └── ExampleCard[]
└── PathEndDialog (当关联词为空时弹出)
```

**沉浸式设计原则：**
- 无 AppBar，使用 Scaffold 的 body 直接布局
- 顶部操作栏透明背景，与页面内容融为一体
- 学习页使用 Stack 让操作栏悬浮在内容上方
- 统一的背景色，无分割线

**页面导航流程：**
```
首页 → InitialChoicePage → LearnPage → (路径结束) → InitialChoicePage
                              ↓
                         (关闭按钮) → 首页
```

### 状态管理

使用 Riverpod 的 NotifierProvider 分别管理两个页面的状态：

```dart
// 初始选择页 Provider
final initialChoiceControllerProvider = NotifierProvider<InitialChoiceController, InitialChoiceState>(
  InitialChoiceController.new
);

// 学习页 Provider
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  LearnController.new
);

// 音频服务 Provider（共享）
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
```

### 数据流（严格单向）

**初始选择页数据流：**
```
用户进入页面
    ↓
InitialChoiceController.loadChoices()
    ↓
WordRepository.getRandomUnmasteredWordsWithMeaning()
    ↓
Database 查询 (words + word_meanings)
    ↓
返回 List<WordChoice>
    ↓
InitialChoiceState 更新 (choices)
    ↓
InitialChoicePage UI 重建
    ↓
用户点击单词卡片
    ↓
导航到 /learn/:wordId
```

**学习页数据流：**
```
用户进入页面 (携带 wordId)
    ↓
LearnController.initWithWord(wordId)
    ↓
WordRepository.getWordDetail(wordId) + getRelatedWords(wordId)
    ↓
Database 查询 (words + meanings + audios + examples + relations)
    ↓
返回 WordDetail + List<WordWithRelation>
    ↓
LearnState 更新 (studyQueue)
    ↓
LearnPage UI 重建
    ↓
用户滑动切换单词
    ↓
LearnController.onPageChanged(newIndex)
    ↓
标记学习状态 + 检查是否需要加载更多关联词
    ↓
LearnState 更新 (currentIndex, learnedWordIds, studyQueue)
    ↓
LearnPage UI 重建
```

**音频播放状态机设计：**

### 音频状态机

```dart
/// 音频播放状态
enum AudioPlayState {
  idle,      // 空闲（未播放）
  loading,   // 加载中
  playing,   // 播放中
  error,     // 错误
}

/// 音频播放状态数据
class AudioPlayStatus {
  final AudioPlayState state;
  final String? currentSource;  // 当前播放的音频源
  final String? errorMessage;   // 错误信息
  
  const AudioPlayStatus({
    this.state = AudioPlayState.idle,
    this.currentSource,
    this.errorMessage,
  });
  
  /// 判断指定音频是否正在播放
  bool isPlaying(String source) => 
    state == AudioPlayState.playing && currentSource == source;
  
  /// 判断指定音频是否正在加载
  bool isLoading(String source) => 
    state == AudioPlayState.loading && currentSource == source;
}
```

**状态转换图：**
```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
    ┌──────────┐  play(source)  ┌──────────┐  loaded   ┌──────────┐
    │   idle   │ ─────────────> │ loading  │ ────────> │ playing  │
    └──────────┘                └──────────┘           └──────────┘
         ▲                           │                      │
         │                           │ error                │ stop/complete
         │                           ▼                      │
         │                      ┌──────────┐                │
         └───────────────────── │  error   │ <──────────────┘
                                └──────────┘
                                     │
                                     │ retry/dismiss
                                     ▼
                                ┌──────────┐
                                │   idle   │
                                └──────────┘
```

### AudioPlayController (音频状态管理)

```dart
/// 音频播放控制器（状态机实现）
class AudioPlayController extends Notifier<AudioPlayStatus> {
  late final AudioService _audioService;
  StreamSubscription? _playerStateSubscription;
  
  @override
  AudioPlayStatus build() {
    _audioService = ref.read(audioServiceProvider);
    _setupPlayerStateListener();
    return const AudioPlayStatus();
  }
  
  /// 监听 AudioPlayer 状态变化
  void _setupPlayerStateListener() {
    _playerStateSubscription = _audioService.player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // 播放完成 → 回到 idle
        state = const AudioPlayStatus(state: AudioPlayState.idle);
      } else if (playerState.playing) {
        // 正在播放
        state = AudioPlayStatus(
          state: AudioPlayState.playing,
          currentSource: _audioService.currentAudioSource,
        );
      }
    });
    
    // 清理订阅
    ref.onDispose(() => _playerStateSubscription?.cancel());
  }
  
  /// 播放音频
  Future<void> play(String source) async {
    // idle/playing → loading
    state = AudioPlayStatus(
      state: AudioPlayState.loading,
      currentSource: source,
    );
    
    try {
      await _audioService.playAudio(source);
      // loading → playing (由 listener 处理)
    } catch (e) {
      // loading → error
      state = AudioPlayStatus(
        state: AudioPlayState.error,
        currentSource: source,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// 停止音频
  Future<void> stop() async {
    await _audioService.stop();
    // playing → idle
    state = const AudioPlayStatus(state: AudioPlayState.idle);
  }
  
  /// 切换播放/停止
  Future<void> toggle(String source) async {
    if (state.isPlaying(source)) {
      await stop();
    } else {
      await play(source);
    }
  }
}

/// Provider
final audioPlayControllerProvider = NotifierProvider<AudioPlayController, AudioPlayStatus>(
  AudioPlayController.new,
);
```

### 页面间数据传递

```
InitialChoicePage                    LearnPage
      │                                  │
      │  context.push('/learn/$wordId')  │
      │ ─────────────────────────────────>│
      │                                  │
      │                                  │ initWithWord(wordId)
      │                                  │ 加载单词详情和关联词
      │                                  │
      │                                  │ 用户学习完成/关闭
      │                                  │
      │  context.pop() 或 go('/initial-choice')
      │ <─────────────────────────────────│
```

## Components and Interfaces

### 1. InitialChoiceState (初始选择页状态)

```dart
/// 单词选择项（包含基本信息和释义列表）
class WordChoice {
  final Word word;
  final List<WordMeaning> meanings;  // 释义列表（显示时取第一个）
  
  const WordChoice({
    required this.word,
    this.meanings = const [],
  });
  
  /// 获取第一个释义（用于显示）
  String? get primaryMeaning => meanings.isNotEmpty ? meanings.first.meaningCn : null;
}

/// 初始选择页状态
class InitialChoiceState {
  final List<WordChoice> choices;  // 5 个随机单词
  final bool isLoading;
  final String? error;
  
  const InitialChoiceState({
    this.choices = const [],
    this.isLoading = false,
    this.error,
  });
  
  InitialChoiceState copyWith({
    List<WordChoice>? choices,
    bool? isLoading,
    String? error,
  }) {
    return InitialChoiceState(
      choices: choices ?? this.choices,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
```

### 2. LearnState (学习页状态)

```dart
/// 学习状态
class LearnState {
  final List<WordDetail> studyQueue;      // 学习队列
  final int currentIndex;                  // 当前索引
  final Set<int> learnedWordIds;          // 已学习单词 ID
  final bool isLoading;
  final bool isLoadingMore;               // 是否正在加载更多关联词
  final bool pathEnded;                   // 路径是否结束
  final String? error;
  
  const LearnState({
    this.studyQueue = const [],
    this.currentIndex = 0,
    this.learnedWordIds = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.pathEnded = false,
    this.error,
  });
  
  /// 当前单词详情
  WordDetail? get currentWordDetail => 
    currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;
  
  /// 已学单词数
  int get learnedCount => learnedWordIds.length;
  
  /// 是否在队列末尾
  bool get isAtQueueEnd => currentIndex >= studyQueue.length - 1;
  
  LearnState copyWith({
    List<WordDetail>? studyQueue,
    int? currentIndex,
    Set<int>? learnedWordIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? pathEnded,
    String? error,
  }) {
    return LearnState(
      studyQueue: studyQueue ?? this.studyQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      learnedWordIds: learnedWordIds ?? this.learnedWordIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pathEnded: pathEnded ?? this.pathEnded,
      error: error ?? this.error,
    );
  }
}
```

### 3. InitialChoiceController (初始选择页控制器)

```dart
class InitialChoiceController extends Notifier<InitialChoiceState> {
  late final WordRepository _wordRepository;
  
  @override
  InitialChoiceState build() {
    _wordRepository = ref.read(wordRepositoryProvider);
    return const InitialChoiceState();
  }
  
  /// 加载 5 个随机未掌握单词
  Future<void> loadChoices() async;
  
  /// 刷新选择（重新随机获取 5 个单词）
  Future<void> refresh() async {
    await loadChoices();  // 复用 loadChoices 逻辑
  }
}
```

### 4. LearnController (学习页控制器)

```dart
class LearnController extends Notifier<LearnState> {
  late final WordRepository _wordRepository;
  late final StudyWordRepository _studyWordRepository;
  late final StudyLogRepository _studyLogRepository;
  late final DailyStatRepository _dailyStatRepository;
  late final AudioService _audioService;
  
  DateTime? _sessionStartTime;
  
  @override
  LearnState build() {
    _wordRepository = ref.read(wordRepositoryProvider);
    _studyWordRepository = ref.read(studyWordRepositoryProvider);
    _studyLogRepository = ref.read(studyLogRepositoryProvider);
    _dailyStatRepository = ref.read(dailyStatRepositoryProvider);
    _audioService = ref.read(audioServiceProvider);
    
    return const LearnState();
  }
  
  /// 初始化学习（传入选中的单词 ID）
  Future<void> initWithWord(int wordId) async;
  
  /// 页面切换回调
  Future<void> onPageChanged(int newIndex) async;
  
  /// 加载关联词
  Future<void> loadRelatedWords(int wordId) async;
  
  /// 标记单词为已学习
  Future<void> markWordAsLearned(int wordId) async;
  
  /// 播放音频
  Future<void> playAudio(String source) async;
  
  /// 更新每日统计
  Future<void> updateDailyStats({required int durationMs}) async;
  
  /// 结束学习会话
  void endSession();
}
```

### 5. WordRepository 扩展

```dart
class WordRepository {
  // 现有方法...
  
  /// 获取随机未掌握的单词（包含释义，用于初始选择）
  Future<List<WordChoice>> getRandomUnmasteredWordsWithMeaning({int count = 5}) async {
    final db = await _db;
    
    // 1. 先获取随机单词
    final wordResults = await db.rawQuery('''
      SELECT w.*
      FROM words w
      LEFT JOIN study_words sw ON w.id = sw.word_id
      WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
      ORDER BY RANDOM()
      LIMIT ?
    ''', [count]);
    
    // 2. 为每个单词获取释义
    final choices = <WordChoice>[];
    for (final wordMap in wordResults) {
      final word = Word.fromMap(wordMap);
      final meanings = await getWordMeanings(word.id);
      choices.add(WordChoice(word: word, meanings: meanings));
    }
    
    return choices;
  }
  
  /// 获取单词的关联词（过滤已掌握）
  Future<List<WordWithRelation>> getRelatedWords(int wordId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT w.*, wr.score, wr.relation_type
      FROM word_relations wr
      JOIN words w ON wr.related_word_id = w.id
      LEFT JOIN study_words sw ON w.id = sw.word_id
      WHERE wr.word_id = ?
        AND (sw.user_state IS NULL OR sw.user_state IN (0, 1))
      ORDER BY wr.score DESC
    ''', [wordId]);
    
    return results.map((map) => WordWithRelation.fromMap(map)).toList();
  }
}
```

### 4. WordWithRelation 模型

```dart
/// 带关联信息的单词
class WordWithRelation {
  final Word word;
  final double score;
  final String relationType;
  
  const WordWithRelation({
    required this.word,
    required this.score,
    required this.relationType,
  });
  
  factory WordWithRelation.fromMap(Map<String, dynamic> map) {
    return WordWithRelation(
      word: Word.fromMap(map),
      score: (map['score'] as num).toDouble(),
      relationType: map['relation_type'] as String? ?? 'semantic',
    );
  }
}
```

### 7. InitialChoicePage (独立页面 - 沉浸式)

```dart
class InitialChoicePage extends ConsumerStatefulWidget {
  @override
  ConsumerState<InitialChoicePage> createState() => _InitialChoicePageState();
}

class _InitialChoicePageState extends ConsumerState<InitialChoicePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(initialChoiceControllerProvider.notifier).loadChoices();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(initialChoiceControllerProvider);
    final controller = ref.read(initialChoiceControllerProvider.notifier);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部操作栏（透明，与页面融为一体）
              _buildTopActions(context, state, controller),
              SizedBox(height: 24),
              // 页面标题
              Text(
                '选择起点',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '选择一个单词开始探索',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 24),
              // 单词选择网格
              Expanded(
                child: state.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: state.choices.length,
                      itemBuilder: (context, index) {
                        final wordChoice = state.choices[index];
                        return WordChoiceCard(
                          wordChoice: wordChoice,
                          onTap: () => context.push('/learn/${wordChoice.word.id}'),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 顶部操作栏（透明背景）
  Widget _buildTopActions(BuildContext context, InitialChoiceState state, InitialChoiceController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 返回按钮
        IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        // 刷新按钮
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: state.isLoading ? null : controller.refresh,
        ),
      ],
    );
  }
}
```

### 6. WordChoiceCard (UI 组件)

```dart
class WordChoiceCard extends StatelessWidget {
  final WordChoice wordChoice;  // 包含 Word 和释义列表
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    final word = wordChoice.word;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word, style: TextStyle(fontSize: 24)),
              Text(word.furigana ?? '', style: TextStyle(fontSize: 14)),
              // 显示第一个释义
              if (wordChoice.primaryMeaning != null)
                Text(wordChoice.primaryMeaning!, style: TextStyle(fontSize: 12)),
              JlptLevelBadge(level: word.jlptLevel),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 9. AudioPlayButton (UI 组件 - 基于状态机)

```dart
/// 音频播放按钮，基于状态机自动响应状态变化
class AudioPlayButton extends ConsumerWidget {
  final String audioSource;
  
  const AudioPlayButton({super.key, required this.audioSource});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioStatus = ref.watch(audioPlayControllerProvider);
    final controller = ref.read(audioPlayControllerProvider.notifier);
    
    // 根据状态机状态决定显示
    final isThisPlaying = audioStatus.isPlaying(audioSource);
    final isThisLoading = audioStatus.isLoading(audioSource);
    
    return IconButton(
      icon: _buildIcon(isThisPlaying, isThisLoading),
      onPressed: isThisLoading 
        ? null  // 加载中禁用点击
        : () => controller.toggle(audioSource),
    );
  }
  
  Widget _buildIcon(bool isPlaying, bool isLoading) {
    if (isLoading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      isPlaying ? Icons.stop_circle : Icons.play_circle,
      size: 32,
    );
  }
}
```

**状态机驱动的 UI 同步机制：**

```
┌─────────────────────────────────────────────────────────────────┐
│                    状态同步流程                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  用户点击按钮                                                    │
│       │                                                         │
│       ▼                                                         │
│  AudioPlayController.toggle(source)                             │
│       │                                                         │
│       ├─── 如果 idle/error ───> play(source)                    │
│       │         │                                               │
│       │         ▼                                               │
│       │    state = loading ──────────────────────┐              │
│       │         │                                │              │
│       │         ▼                                │              │
│       │    AudioService.playAudio()              │              │
│       │         │                                │              │
│       │         ▼                                │              │
│       │    playerStateStream 发出事件            │              │
│       │         │                                │              │
│       │         ▼                                │              │
│       │    _setupPlayerStateListener 接收        │              │
│       │         │                                │              │
│       │         ▼                                │              │
│       │    state = playing ──────────────────────┤              │
│       │                                          │              │
│       └─── 如果 playing ───> stop()              │              │
│                 │                                │              │
│                 ▼                                │              │
│            AudioService.stop()                   │              │
│                 │                                │              │
│                 ▼                                │              │
│            state = idle ─────────────────────────┤              │
│                                                  │              │
│                                                  ▼              │
│                                    Riverpod 检测到 state 变化    │
│                                                  │              │
│                                                  ▼              │
│                                    所有 watch 该 provider 的     │
│                                    Widget 自动 rebuild           │
│                                                  │              │
│                                                  ▼              │
│                                    AudioPlayButton.build()      │
│                                    根据新 state 渲染对应图标     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**关键同步点：**
1. `state = xxx` 赋值触发 Riverpod 状态更新
2. `ref.watch(audioPlayControllerProvider)` 订阅状态变化
3. 状态变化 → Riverpod 自动调用 Widget.build()
4. build() 中根据 `audioStatus.isPlaying(source)` 决定图标

**多按钮场景同步：**
```dart
// 页面上有多个 AudioPlayButton
AudioPlayButton(audioSource: 'word_audio_1.mp3')   // 单词音频
AudioPlayButton(audioSource: 'example_audio_1.mp3') // 例句1音频
AudioPlayButton(audioSource: 'example_audio_2.mp3') // 例句2音频

// 当播放 word_audio_1.mp3 时：
// - audioStatus.currentSource = 'word_audio_1.mp3'
// - audioStatus.state = playing
// 
// 所有按钮都会 rebuild，但只有 source 匹配的按钮显示停止图标
// isPlaying('word_audio_1.mp3') = true  → 显示停止图标
// isPlaying('example_audio_1.mp3') = false → 显示播放图标
// isPlaying('example_audio_2.mp3') = false → 显示播放图标
```

**播放完成自动同步：**
```dart
// playerStateStream 监听器
_audioService.player.playerStateStream.listen((playerState) {
  if (playerState.processingState == ProcessingState.completed) {
    // 播放完成，自动回到 idle
    state = const AudioPlayStatus(state: AudioPlayState.idle);
    // → 触发所有按钮 rebuild → 所有按钮显示播放图标
  }
});
```

## Data Models

### LearnState 完整定义

```dart
enum LearnPhase { choice, learning, pathEnd }

class LearnState {
  final LearnPhase phase;
  final List<WordDetail> initialChoices;
  final List<WordDetail> studyQueue;
  final int currentIndex;
  final Set<int> learnedWordIds;
  final bool isLoading;
  final String? playingAudioSource;
  final String? error;
  
  const LearnState({
    this.phase = LearnPhase.choice,
    this.initialChoices = const [],
    this.studyQueue = const [],
    this.currentIndex = 0,
    this.learnedWordIds = const {},
    this.isLoading = false,
    this.playingAudioSource,
    this.error,
  });
  
  LearnState copyWith({
    LearnPhase? phase,
    List<WordDetail>? initialChoices,
    List<WordDetail>? studyQueue,
    int? currentIndex,
    Set<int>? learnedWordIds,
    bool? isLoading,
    String? playingAudioSource,
    String? error,
  }) {
    return LearnState(
      phase: phase ?? this.phase,
      initialChoices: initialChoices ?? this.initialChoices,
      studyQueue: studyQueue ?? this.studyQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      learnedWordIds: learnedWordIds ?? this.learnedWordIds,
      isLoading: isLoading ?? this.isLoading,
      playingAudioSource: playingAudioSource ?? this.playingAudioSource,
      error: error ?? this.error,
    );
  }
  
  WordDetail? get currentWordDetail => 
    currentIndex < studyQueue.length ? studyQueue[currentIndex] : null;
  
  int get learnedCount => learnedWordIds.length;
  
  bool get isAtQueueEnd => currentIndex >= studyQueue.length - 1;
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

基于 prework 分析，以下属性经过合并和去重后保留：

### Property 1: 初始选择返回未掌握单词

*For any* 数据库状态，调用 getRandomUnmasteredWords(5) 返回的所有单词都应该是未掌握的（user_state != 2），且数量不超过 5 个。

**Validates: Requirements 1.1**

### Property 2: 选择单词后加载关联词

*For any* 单词 ID，调用 selectWord 后，studyQueue 应该包含该单词的所有未掌握关联词。

**Validates: Requirements 1.4**

### Property 3: 单词详情包含完整数据

*For any* 单词 ID，调用 getWordDetail 返回的 WordDetail 应该包含 word、meanings、audios、examples 所有关联数据。

**Validates: Requirements 2.1**

### Property 4: 音频按钮状态同步

*For any* 音频源，当 AudioService.currentState == playing 且 currentAudioSource == source 时，对应的播放按钮应该显示播放中状态。

**Validates: Requirements 2.3**

### Property 5: 向左滑动递增索引

*For any* 学习队列和当前索引（不是最后一个），向左滑动应该使 currentIndex 递增 1。

**Validates: Requirements 2.6**

### Property 6: 向右滑动递减索引

*For any* 学习队列和当前索引（不是第一个），向右滑动应该使 currentIndex 递减 1。

**Validates: Requirements 2.7**

### Property 7: 队列末尾触发关联词加载

*For any* 学习队列，当 currentIndex 到达队列末尾时，应该基于当前单词加载新的关联词。

**Validates: Requirements 3.1**

### Property 8: 关联词追加到队列

*For any* 学习队列，当关联词加载完成时，新单词应该被追加到队列末尾，队列长度应该增加。

**Validates: Requirements 3.2**

### Property 9: 关联词过滤已掌握单词

*For any* 单词 ID，调用 getRelatedWords 返回的所有单词都应该是未掌握的（user_state != 2）。

**Validates: Requirements 3.3**

### Property 10: 滑动离开标记学习状态

*For any* 单词，当用户向左滑动离开该单词时，该单词的 ID 应该被添加到 learnedWordIds 集合中。

**Validates: Requirements 4.1**

### Property 11: 标记学习状态更新数据库

*For any* 单词 ID，当调用 markWordAsLearned 后，study_words 表中应该有对应记录且 user_state = 1。

**Validates: Requirements 4.2**

### Property 12: 标记学习状态插入日志

*For any* 单词 ID，当调用 markWordAsLearned 后，study_logs 表中应该有对应记录且 log_type = 1。

**Validates: Requirements 4.3**

### Property 13: 不重复标记已学习单词

*For any* 单词 ID，如果该 ID 已在 learnedWordIds 中，再次滑动离开时不应该重复调用 markWordAsLearned。

**Validates: Requirements 4.4**

### Property 14: 已学计数等于集合大小

*For any* 学习状态，显示的已学单词数应该等于 learnedWordIds.length。

**Validates: Requirements 5.1, 5.2**

### Property 15: 累加更新每日统计

*For any* 学习会话，当当天已有学习记录时，updateDailyStats 应该累加更新学习时长和已学单词数，而不是覆盖。

**Validates: Requirements 6.5**

## Error Handling

### 错误处理策略

1. **数据库查询失败**
   - 记录错误日志
   - 显示友好的错误提示
   - 提供重试选项

2. **关联词加载失败**
   - 记录错误日志
   - 不影响当前学习流程
   - 用户可继续学习现有单词

3. **音频播放失败**
   - 记录错误日志
   - 显示简短提示
   - 不影响学习流程

4. **统计更新失败**
   - 记录错误日志
   - 不影响用户体验
   - 下次启动时重试

## Testing Strategy

### Unit Testing

使用 Flutter 的 test 包进行单元测试：

1. **LearnController 业务逻辑**
   - 测试 loadInitialChoices 方法是否正确加载 5 个单词
   - 测试 selectWord 方法是否正确加载关联词
   - 测试 onPageChanged 方法是否正确更新索引和标记学习状态
   - 测试 loadRelatedWords 方法是否正确追加关联词
   - 测试 markWordAsLearned 方法是否正确更新状态和数据库

2. **Repository 数据访问**
   - 测试 getRandomUnmasteredWords 方法是否正确过滤已掌握单词
   - 测试 getRelatedWords 方法是否正确查询关联词
   - 测试 markAsLearned 方法是否正确更新数据库

3. **LearnState 扩展方法**
   - 测试 currentWordDetail getter 是否返回正确的单词
   - 测试 learnedCount getter 是否返回正确的数量
   - 测试 isAtQueueEnd getter 是否正确判断队列末尾

### Property-Based Testing

使用 Dart 的 `test` 包进行属性测试，配置每个测试运行至少 100 次迭代。

每个属性测试必须使用注释标记对应的设计文档中的属性编号：

```dart
// Feature: associative-learn-mode, Property 1: 初始选择返回未掌握单词
test('property: initial choices are unmastered words', () {
  // 测试代码
});
```

## Implementation Notes

### 关键实现细节

**1. 初始选择页加载（InitialChoiceController）**
```dart
Future<void> loadChoices() async {
  state = state.copyWith(isLoading: true);
  
  try {
    // 获取 Word 基本信息和第一个释义
    final wordChoices = await _wordRepository.getRandomUnmasteredWordsWithMeaning(count: 5);
    
    state = state.copyWith(
      choices: wordChoices,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
  }
}
```

**2. 初始化学习（LearnController）**
```dart
Future<void> initWithWord(int wordId) async {
  _sessionStartTime = DateTime.now();
  state = state.copyWith(isLoading: true);
  
  try {
    // 获取选中单词的详情
    final selectedWord = await _wordRepository.getWordDetail(wordId);
    if (selectedWord == null) {
      state = state.copyWith(isLoading: false, error: '单词不存在');
      return;
    }
    
    // 加载关联词
    final relatedWords = await _wordRepository.getRelatedWords(wordId);
    final relatedDetails = await Future.wait(
      relatedWords.map((w) => _wordRepository.getWordDetail(w.word.id))
    );
    
    state = state.copyWith(
      studyQueue: [selectedWord, ...relatedDetails.whereType<WordDetail>()],
      currentIndex: 0,
      isLoading: false,
    );
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
  }
}
```

**3. 页面切换处理**
```dart
Future<void> onPageChanged(int newIndex) async {
  // 向前滑动时标记上一个单词
  if (newIndex > state.currentIndex) {
    final previousWordId = state.studyQueue[state.currentIndex].word.id;
    if (!state.learnedWordIds.contains(previousWordId)) {
      await markWordAsLearned(previousWordId);
    }
  }
  
  state = state.copyWith(currentIndex: newIndex);
  
  // 检查是否到达队列末尾
  if (state.isAtQueueEnd) {
    await loadRelatedWords(state.currentWordDetail!.word.id);
  }
}
```

**4. 加载关联词**
```dart
Future<void> loadRelatedWords(int wordId) async {
  final relatedWords = await _wordRepository.getRelatedWords(wordId);
  
  if (relatedWords.isEmpty) {
    // 断链：返回初始选择页
    state = state.copyWith(phase: LearnPhase.pathEnd);
    return;
  }
  
  final relatedDetails = await Future.wait(
    relatedWords.map((w) => _wordRepository.getWordDetail(w.word.id))
  );
  
  state = state.copyWith(
    studyQueue: [...state.studyQueue, ...relatedDetails.whereType<WordDetail>()],
  );
}
```

**5. 音频播放与状态同步**
```dart
Future<void> playAudio(String source) async {
  await _audioService.playAudio(source);
  // AudioService 内部管理状态，UI 通过 ref.watch(audioServiceProvider) 监听
}
```

**6. PageView 配置**
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
    return SingleChildScrollView(
      child: Column(
        children: [
          WordCard(wordDetail: wordDetail),
          ...wordDetail.examples.map((e) => ExampleCard(example: e)),
        ],
      ),
    );
  },
)
```

### 文件结构

```
lib/features/learn/
├── controller/
│   ├── initial_choice_controller.dart  # 初始选择页控制器
│   └── learn_controller.dart           # 学习页控制器
├── state/
│   ├── initial_choice_state.dart       # 初始选择页状态
│   └── learn_state.dart                # 学习页状态
├── pages/
│   ├── initial_choice_page.dart        # 初始选择页（独立）
│   └── learn_page.dart                 # 学习页（独立）
└── widgets/
    ├── word_card.dart                  # 单词卡片
    ├── word_choice_card.dart           # 选择卡片
    ├── example_card.dart               # 例句卡片
    └── audio_play_button.dart          # 音频播放按钮
```

### 路由配置

```dart
// 在 app_router.dart 中添加
GoRoute(
  path: '/initial-choice',
  builder: (context, state) => const InitialChoicePage(),
),
GoRoute(
  path: '/learn/:wordId',
  builder: (context, state) {
    final wordId = int.parse(state.pathParameters['wordId']!);
    return LearnPage(initialWordId: wordId);
  },
),
```

## Dependencies

- `flutter/services.dart`: 用于触觉反馈 (HapticFeedback)
- `just_audio`: 音频播放
- `flutter_riverpod`: 状态管理
- 现有依赖保持不变
