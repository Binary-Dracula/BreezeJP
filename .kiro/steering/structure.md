---
inclusion: always
---

# 项目架构与文件组织

## 架构模式

功能优先架构（Feature-First），按功能模块组织代码：

```
lib/
├── core/              # 共享层
│   ├── constants/     # 应用级常量
│   ├── utils/         # 工具函数
│   └── widgets/       # 可复用 UI 组件
├── data/              # 数据层
│   ├── db/            # 数据库管理（AppDatabase 单例）
│   │   └── app_database.dart
│   ├── models/        # 数据模型（Word、ExampleSentence 等）
│   │   ├── word.dart
│   │   ├── word_meaning.dart
│   │   ├── word_audio.dart
│   │   ├── example_sentence.dart
│   │   └── example_audio.dart
│   └── repositories/  # 数据访问层（Repository 模式）
├── features/          # 功能模块
│   ├── splash/        # 启动页面（已实现）
│   │   ├── controller/
│   │   │   └── splash_controller.dart
│   │   ├── pages/
│   │   │   └── splash_page.dart
│   │   ├── state/
│   │   │   └── splash_state.dart
│   │   └── README.md
│   ├── home/          # 主页面（已实现）
│   │   └── pages/
│   │       └── home_page.dart
│   ├── learn/         # 学习功能（待实现）
│   │   ├── controller/
│   │   ├── pages/
│   │   ├── state/
│   │   └── widgets/
│   ├── review/        # 复习功能（待实现）
│   ├── settings/      # 设置功能（待实现）
│   └── word_detail/   # 单词详情（待实现）
├── l10n/              # 国际化文件
│   ├── app_zh.arb     # 中文翻译（模板）
│   ├── app_ja.arb     # 日语翻译
│   ├── app_en.arb     # 英语翻译
│   ├── app_localizations.dart        # 自动生成
│   ├── app_localizations_zh.dart     # 自动生成
│   ├── app_localizations_ja.dart     # 自动生成
│   ├── app_localizations_en.dart     # 自动生成
│   └── README.md
├── router/            # 路由配置（go_router）
│   └── app_router.dart
├── services/          # 业务逻辑服务
└── main.dart          # 应用入口
```

## 功能模块结构

每个功能模块遵循统一结构：

```
features/[功能名]/
├── controller/    # Riverpod 控制器（Notifier 或 AsyncNotifier）
├── pages/         # 页面级组件（路由目标）
├── state/         # 状态类定义（不可变数据类）
└── widgets/       # 功能内可复用组件
```

### 已实现的功能模块

#### Splash 模块
- **功能**: 应用启动页面，处理数据库初始化等预处理任务
- **文件**:
  - `splash_controller.dart` - 使用 `NotifierProvider` 管理初始化流程
  - `splash_page.dart` - UI 页面，显示加载状态和错误信息
  - `splash_state.dart` - 状态类，包含 isLoading、message、error、isInitialized
- **特点**: 自动初始化完成后跳转到主页

#### Home 模块
- **功能**: 主页面，应用的入口界面
- **文件**:
  - `home_page.dart` - 主页 UI，显示欢迎信息和导航按钮
- **特点**: 使用国际化文本，支持中日英三语

## 文件放置规则

### 新建数据模型
- **路径**: `lib/data/models/`
- **命名**: `[实体名].dart`（例：`word.dart`、`word_meaning.dart`）
- **必须实现**: 
  - `fromMap(Map<String, dynamic> map)` - 从数据库反序列化
  - `toMap()` - 序列化到数据库
- **示例**: 
  ```dart
  class Word {
    final int id;
    final String word;
    final String? furigana;
    
    Word({required this.id, required this.word, this.furigana});
    
    factory Word.fromMap(Map<String, dynamic> map) {
      return Word(
        id: map['id'] as int,
        word: map['word'] as String,
        furigana: map['furigana'] as String?,
      );
    }
    
    Map<String, dynamic> toMap() {
      return {'id': id, 'word': word, 'furigana': furigana};
    }
  }
  ```

### 新建功能模块
- **路径**: `lib/features/[功能名]/`
- **必须创建的子目录**:
  - `controller/` - Riverpod 控制器
  - `pages/` - 页面级组件
  - `state/` - 状态类定义
  - `widgets/` - 功能内可复用组件（可选）
- **命名规范**:
  - Controller: `[功能名]_controller.dart`
  - State: `[功能名]_state.dart`
  - Page: `[功能名]_page.dart`
- **示例**: 
  ```dart
  // splash_controller.dart
  final splashControllerProvider = 
      NotifierProvider<SplashController, SplashState>(SplashController.new);
  
  class SplashController extends Notifier<SplashState> {
    @override
    SplashState build() => const SplashState();
    
    Future<void> initialize(BuildContext context) async {
      // 初始化逻辑
    }
  }
  ```

### 新建 Repository
- **路径**: `lib/data/repositories/`
- **命名**: `[实体名]_repository.dart`（例：`word_repository.dart`）
- **职责**: 封装所有数据库操作，返回 Model 对象
- **访问数据库**: 通过 `AppDatabase.instance.database`
- **示例**:
  ```dart
  class WordRepository {
    Future<List<Word>> getWordsByLevel(String jlptLevel) async {
      final db = await AppDatabase.instance.database;
      final results = await db.query(
        'words',
        where: 'jlpt_level = ?',
        whereArgs: [jlptLevel],
      );
      return results.map((map) => Word.fromMap(map)).toList();
    }
  }
  ```

### 新建共享组件
- **路径**: `lib/core/widgets/`
- **用途**: 跨功能模块复用的 UI 组件
- **命名**: `[组件名]_widget.dart` 或 `[组件名].dart`
- **示例**: `loading_indicator.dart`、`error_view.dart`

### 新建工具函数
- **路径**: `lib/core/utils/`
- **特点**: 纯函数，无状态，无副作用
- **命名**: `[功能名]_utils.dart`
- **示例**: `date_utils.dart`、`string_utils.dart`

### 新建常量
- **路径**: `lib/core/constants/`
- **命名**: `[类别]_constants.dart`
- **示例**: `app_constants.dart`、`color_constants.dart`

### 国际化文本
- **路径**: `lib/l10n/`
- **文件**: 
  - `app_zh.arb` - 中文（模板文件）
  - `app_ja.arb` - 日语
  - `app_en.arb` - 英语
- **使用**: 
  ```dart
  final l10n = AppLocalizations.of(context)!;
  Text(l10n.appName);
  ```
- **添加新翻译**: 在所有 .arb 文件中添加相同的键，保存后自动生成代码

## 资源文件组织

```
assets/
├── audio/
│   ├── words/      # 单词音频（命名：单词_romaji_voice_source.mp3）
│   └── examples/   # 例句音频（命名：sentence_[id]_voice_source.mp3）
├── database/
│   └── breeze_jp.sqlite  # 预置数据库
└── images/         # 图片资源
```

## 数据库访问模式

### 单例模式访问
```dart
// 获取数据库实例（单例）
final db = await AppDatabase.instance.database;

// 查询示例
final results = await db.query('words', where: 'jlpt_level = ?', whereArgs: ['N5']);
```

### 通过 Repository 访问（推荐）
```dart
// 在 Repository 中封装数据库操作
class WordRepository {
  Future<List<Word>> getWordsByLevel(String jlptLevel) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query(
      'words',
      where: 'jlpt_level = ?',
      whereArgs: [jlptLevel],
    );
    return results.map((map) => Word.fromMap(map)).toList();
  }
}

// 在 Controller 中调用 Repository
class LearnController extends Notifier<LearnState> {
  final _wordRepository = WordRepository();
  
  Future<void> loadWords() async {
    final words = await _wordRepository.getWordsByLevel('N5');
    state = state.copyWith(words: words);
  }
}
```

### 数据库初始化
- 首次启动时，`AppDatabase` 会自动从 `assets/database/breeze_jp.sqlite` 复制数据库到应用文档目录
- 后续启动直接使用已复制的数据库
- 初始化逻辑在 `SplashController` 中执行

## 路由配置

使用 `go_router` 进行声明式路由管理：

```dart
// lib/router/app_router.dart
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    // 添加更多路由...
  ],
);
```

### 路由导航
```dart
// 跳转到指定路由
context.go('/home');

// 带参数跳转
context.go('/word-detail', extra: wordId);

// 返回上一页
context.pop();
```

## 状态管理

使用 **Riverpod 3.x** 的 `Notifier` 模式：

### Provider 定义
```dart
// 定义 Provider
final myControllerProvider = 
    NotifierProvider<MyController, MyState>(MyController.new);

// 控制器类
class MyController extends Notifier<MyState> {
  @override
  MyState build() => const MyState();
  
  void updateData() {
    state = state.copyWith(data: newData);
  }
}
```

### 在 UI 中使用
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);
    
    return Column(
      children: [
        Text(state.data),
        ElevatedButton(
          onPressed: () {
            ref.read(myControllerProvider.notifier).updateData();
          },
          child: Text('Update'),
        ),
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

## 国际化 (i18n)

### 配置
- 配置文件: `l10n.yaml`
- 翻译文件: `lib/l10n/app_*.arb`
- 支持语言: 中文 (zh)、日语 (ja)、英语 (en)

### 使用方法
```dart
import '../../../l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        Text(l10n.appName),
        Text(l10n.homeWelcome),
        Text(l10n.splashInitFailed('数据库错误')),
      ],
    );
  }
}
```

### 添加新翻译
1. 在 `app_zh.arb` 中添加键值对
2. 在 `app_ja.arb` 和 `app_en.arb` 中添加对应翻译
3. 保存文件，Flutter 自动生成代码
4. 在代码中使用 `l10n.newKey`

## 测试文件组织

测试文件镜像源代码结构：

```
test/
├── features/       # 功能测试
│   ├── splash/
│   └── home/
├── data/           # 数据层测试
│   ├── models/
│   └── repositories/
└── utils/          # 工具函数测试
```

## 项目当前状态

### ✅ 已实现
- 应用入口和基础配置
- Splash 启动页面（数据库初始化）
- Home 主页面（框架）
- 数据库管理（AppDatabase 单例）
- 数据模型（Word、WordMeaning、ExampleSentence 等）
- 路由配置（go_router）
- 国际化支持（中日英三语）
- Riverpod 状态管理

### 🚧 待实现
- 学习功能（learn）
- 复习功能（review）
- 设置功能（settings）
- 单词详情（word_detail）
- Repository 层
- 音频播放服务
- 共享 UI 组件

## 开发流程建议

### 新增功能模块的步骤

1. **创建目录结构**
   ```bash
   mkdir -p lib/features/[功能名]/{controller,pages,state,widgets}
   ```

2. **定义状态类** (`state/[功能名]_state.dart`)
   ```dart
   class MyState {
     final bool isLoading;
     final List<Data> data;
     final String? error;
     
     const MyState({
       this.isLoading = false,
       this.data = const [],
       this.error,
     });
     
     MyState copyWith({...}) { ... }
   }
   ```

3. **创建控制器** (`controller/[功能名]_controller.dart`)
   ```dart
   final myControllerProvider = 
       NotifierProvider<MyController, MyState>(MyController.new);
   
   class MyController extends Notifier<MyState> {
     @override
     MyState build() => const MyState();
     
     Future<void> loadData() async { ... }
   }
   ```

4. **创建页面** (`pages/[功能名]_page.dart`)
   ```dart
   class MyPage extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final state = ref.watch(myControllerProvider);
       return Scaffold(...);
     }
   }
   ```

5. **添加路由** (`router/app_router.dart`)
   ```dart
   GoRoute(
     path: '/my-feature',
     name: 'myFeature',
     builder: (context, state) => const MyPage(),
   ),
   ```

6. **添加国际化文本** (`l10n/app_*.arb`)
   ```json
   {
     "myFeatureTitle": "我的功能",
     "myFeatureButton": "点击按钮"
   }
   ```
