# BreezeJP 开发指南

## 产品概述

BreezeJP 是一款追求极致"心流"体验的日语单词记忆 App。采用全屏沉浸式交互（类似 TikTok）和关联语义探索（类似维基百科漫游），解决背单词枯燥和"孤岛记忆"的问题。

### 核心价值
- **沉浸感**：去 UI 化，全屏展示
- **清晰交互**：左右滑动切换单词，上下滑动查看详情
- **关联性**：学完"狗"推荐"猫"，建立语义网络
- **掌控感**：通过分支选择避免难度失控，用户决定学习路径
- **自由度**：无每日新词上限，用户可无限探索
- **科学性**：底层支持 SM-2 与 FSRS 双算法引擎

## 技术栈

**Flutter 3.38.1** (Dart SDK ^3.10.0) - 跨平台移动应用

### 核心依赖

| 类别     | 包名                      | 用途                                                  |
| -------- | ------------------------- | ----------------------------------------------------- |
| 状态管理 | flutter_riverpod ^3.0.3   | MVVM 状态管理（使用 `NotifierProvider`）              |
| 数据库   | sqflite ^2.3.3            | SQLite 本地数据库（通过 `AppDatabase.instance` 访问） |
| 路由     | go_router ^17.0.0         | 声明式路由（`context.go()`, `context.pop()`）         |
| 音频     | just_audio ^0.10.5        | 音频播放（通过 `AudioService` 封装）                  |
| UI       | ruby_text ^3.0.3          | 日文假名注音渲染                                      |
| 动画     | flutter_animate ^4.5.0    | 声明式动画                                            |
| 手势     | gesture_x_detector ^1.1.1 | 高级手势识别                                          |
| 工具     | kana_kit ^2.1.1           | 假名/罗马音转换                                       |
| 网络     | dio ^5.7.0                | HTTP 客户端                                           |
| 日志     | logger ^2.5.0             | 日志输出（通过 `lib/core/utils/app_logger.dart`）     |
| 国际化   | intl ^0.20.2              | 多语言支持（`AppLocalizations`）                      |

## 架构模式：MVVM + Repository + Riverpod

```
View (ConsumerWidget) ←→ Controller (Notifier) ←→ Repository ←→ Database (AppDatabase.instance)
                              ↕
                          State (Immutable)
```

### 层级职责与约束

| 层级           | 职责                                           | 禁止事项                              |
| -------------- | ---------------------------------------------- | ------------------------------------- |
| **View**       | UI 渲染、用户交互、使用 `ref.watch()` 订阅状态 | ❌ 数据库访问、业务逻辑、状态直接修改 |
| **Controller** | 业务逻辑、状态管理、调用 Repository            | ❌ 数据处理逻辑、直接数据库查询       |
| **State**      | 不可变数据容器、必须有 `copyWith()`            | ❌ 可变字段、包含逻辑                 |
| **Repository** | CRUD 操作、返回 Model 对象                     | ❌ 业务逻辑、返回 Map 对象            |
| **Model**      | 数据结构、必须实现 `fromMap()`/`toMap()`       | ❌ 业务逻辑                           |

**关键规则**：
- ✅ 数据库访问唯一路径：Repository → Controller → View
- ✅ Repository 必须返回 Model 对象，禁止返回 `Map<String, dynamic>`
- ✅ 所有 State 类必须不可变（`@immutable`）并提供 `copyWith()` 方法
- ✅ 使用 `AppDatabase.instance` 单例访问数据库

## 项目结构

```
lib/
├── core/                    # 共享基础能力
│   ├── algorithm/           # SRS 算法 (SM-2, FSRS)
│   ├── constants/           # 全局常量
│   ├── network/             # HTTP 客户端、接口定义
│   ├── utils/               # 工具（logger、l10n 等）
│   └── widgets/             # 可复用 UI 组件
├── data/                    # 数据层
│   ├── db/                  # 数据库单例 (AppDatabase)
│   ├── models/              # 数据模型 (fromMap/toMap)
│   └── repositories/        # CRUD + providers
├── features/                # 功能模块（MVVM）
│   ├── splash/              # ✅ Splash
│   ├── home/                # ✅ 首页 Dashboard
│   ├── learn/               # ✅ 单词学习流
│   ├── kana/                # 🚧 假名学习
│   ├── review/              # 📋 复习模式
│   ├── word_detail/         # 📋 单词详情
│   ├── word_list/           # 📋 单词列表
│   └── settings/            # 📋 设置
├── l10n/                    # 国际化
├── router/                  # go_router 路由
├── services/                # 横切服务（音频等）
└── main.dart

assets/
├── audio/
│   ├── words/               # 单词发音
│   ├── examples/            # 例句音频
│   └── kana/                # 假名发音
├── database/
│   └── breeze_jp.sqlite     # 预置 SQLite
└── images/
```

### Feature 模块标准结构

```
features/[feature_name]/
├── controller/              # 业务逻辑 (Riverpod Notifier)
│   └── [feature]_controller.dart
├── pages/                   # UI 入口 (ConsumerWidget/Stateful)
│   └── [feature]_page.dart
├── state/                   # 不可变状态
│   └── [feature]_state.dart
└── widgets/                 # 该 feature 专属组件（可选）
    └── [component]_widget.dart
```

## 数据库架构

**数据库**：位于 `assets/database/breeze_jp.sqlite` 的本地 SQLite  
**访问方式**：必须通过 `AppDatabase.instance` 单例  
**16 张核心表**：

- **单词学习**：words、word_meanings、word_audio、example_sentences、example_audio、word_relations
- **用户进度**：study_words、study_logs、daily_stats、users、app_state
- **假名学习**：kana_letters、kana_audio、kana_examples、kana_learning_state、kana_logs、kana_stroke_order

### 关键表结构

#### study_words（单词学习进度）
- `user_state`: 0=未学, 1=学习中, 2=已掌握, 3=忽略
- `next_review_at`: 下一次复习时间戳（NULL 表示未排期）
- `interval`: SM-2 间隔（天）
- `ease_factor`: SM-2 难度系数（默认 2.5）
- `stability`、`difficulty`: FSRS 参数（默认 0）

#### kana_learning_state（假名学习进度）
- `learning_status`: 0=未学习, 1=学习中, 2=已掌握, 3=忽略
- 兼容 SM-2 与 FSRS

### Repository 实现规范

```dart
class WordRepository {
  // ✅ 正确：返回 Model 对象
  Future<List<Word>> getWordsByLevel(String level) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query(
      'words',
      where: 'jlpt_level = ?',
      whereArgs: [level],
    );
    return results.map((map) => Word.fromMap(map)).toList();
  }

  // ❌ 错误：禁止返回 Map
  Future<List<Map<String, dynamic>>> getWords() async { ... }
}
```

### 模型类要求

```dart
class Word {
  final int id;
  final String word;
  final String? furigana;
  final String? jlptLevel;  // 注意：snake_case → camelCase

  Word({required this.id, required this.word, this.furigana, this.jlptLevel});

  // 必须实现：从数据库 Map 转换为 Dart 对象
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int,
      word: map['word'] as String,
      furigana: map['furigana'] as String?,
      jlptLevel: map['jlpt_level'] as String?,  // snake_case in DB
    );
  }

  // 必须实现：从 Dart 对象转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'furigana': furigana,
      'jlpt_level': jlptLevel,  // camelCase → snake_case
    };
  }
}
```

## Riverpod 状态管理

### Provider 定义
```dart
final myControllerProvider = NotifierProvider<MyController, MyState>(
  MyController.new,
);
```

### Controller（业务逻辑）
```dart
class MyController extends Notifier<MyState> {
  @override
  MyState build() => const MyState();

  Future<void> loadData() async {
    final repository = ref.read(myRepositoryProvider);
    final data = await repository.getData();
    state = state.copyWith(data: data);  // 不可变更新
  }
}
```

### State（不可变数据）
```dart
@immutable
class MyState {
  final bool isLoading;
  final List<Word> words;

  const MyState({this.isLoading = false, this.words = const []});

  MyState copyWith({bool? isLoading, List<Word>? words}) {
    return MyState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
    );
  }
}
```

### View（UI）
```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);  // 订阅状态变化
    final controller = ref.read(myControllerProvider.notifier);  // 调用方法

    return Scaffold(
      body: state.isLoading
        ? CircularProgressIndicator()
        : ListView(...),
    );
  }
}
```

**使用规则**：
- `ref.watch()` - 订阅状态变化（触发重建）
- `ref.read()` - 一次性读取或调用方法（不触发重建）
- State 类必须不可变并提供 `copyWith()`

## 代码规范

### 1. 国际化（i18n）- 强制规则

**⚠️ 所有用户可见文本必须使用 `AppLocalizations`，严禁硬编码字符串**

```dart
// ✅ 正确
final l10n = AppLocalizations.of(context)!;
Text(l10n.startLearning);
Button(onPressed: () {}, child: Text(l10n.cancelButton));

// ❌ 错误 - 禁止硬编码
Text('开始学习');
Button(onPressed: () {}, child: Text('取消'));
```

**命名约定**：
- 按钮：`{action}Button` (如 `startButton`, `cancelButton`)
- 标题：`{page}Title` (如 `homeTitle`, `settingsTitle`)
- 提示：`{context}Hint` (如 `searchHint`, `emptyHint`)
- 错误：`{context}Error` (如 `networkError`, `loadError`)
- 标签：`{context}Label` (如 `levelLabel`, `countLabel`)

### 2. 日志规范

**使用 `logger` 包，禁止使用 `print()`**

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';

// ✅ 正确
logger.i('用户开始学习 Session');
logger.d('加载单词详情: wordId=$wordId');
logger.w('音频文件不存在: $audioPath');
logger.e('数据库查询失败', error: e, stackTrace: stackTrace);

// ❌ 错误
print('这是不规范的日志');
```

**日志级别**：
- `logger.t()` - Trace：详细调试信息（开发阶段）
- `logger.d()` - Debug：调试信息（开发阶段）
- `logger.i()` - Info：关键流程节点（应用启动、用户操作）
- `logger.w()` - Warning：可恢复的异常（文件缺失）
- `logger.e()` - Error：需要关注的异常（数据库错误）
- `logger.f()` - Fatal：致命错误（应用崩溃级别）

### 3. 命名规范

| 类型       | 格式           | 示例                                        |
| ---------- | -------------- | ------------------------------------------- |
| 文件名     | snake_case     | `app_database.dart`, `word_repository.dart` |
| 类名       | PascalCase     | `AppDatabase`, `WordRepository`             |
| 变量/函数  | camelCase      | `wordId`, `getUserById()`                   |
| 数据库列名 | snake_case     | `word_id`, `jlpt_level`, `created_at`       |
| 常量       | lowerCamelCase | `defaultEaseFactor`, `maxRetryCount`        |

### 4. 时间戳处理

```dart
// 数据库存储 Unix 时间戳（秒），Dart 使用毫秒
// 读取
final timestamp = map['created_at'] as int;
final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

// 写入
final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
```

## 首页（Dashboard）设计

首页是 BreezeJP 的学习控制中心，采用卡片式布局，包含：

1. **Header（顶部区域）**：问候语、用户昵称、设置按钮
2. **Primary Actions（学习主入口）**：学习新单词、学习五十音图
3. **Review Section（复习模块）**：复习单词、复习五十音图
4. **Stats Card（学习统计）**：今日学习数据、累计数据
5. **Tools Grid（工具区）**：单词本、详细统计等

### 设计原则
- 学习入口优先：Primary Actions 是首页顶部主入口
- 复习模块独立：复习内容与学习入口分区
- 五十音模块独立：与单词体系并行，不交叉混淆
- 空状态友好：新用户看到温和的引导文案
- 不追踪学习进度：保持心流体验，无进度条

## UI/UX 规范

- **手势**：学习模式左右滑动切换单词
- **震动反馈**：页面切换时触发 `HapticFeedback.lightImpact()`
- **进度反馈**：右上角显示本次 Session 计数器（本次已学 +5）
- **日文文本**：使用 `ruby_text` 包显示假名注音
- **例句高亮**：使用 `<b>` 标签，View 层解析显示
- **音频播放**：通过 `AudioService` 封装

## 路由导航

```dart
context.go('/home');                          // 导航到路由
context.go('/word-detail', extra: wordId);    // 传递参数
context.pop();                                // 返回
context.replace('/login');                    // 替换当前路由
```

## 构建与测试命令

```bash
# 依赖管理
flutter pub get
flutter pub upgrade

# 运行
flutter run                    # 默认设备
flutter run -d chrome          # Web
flutter run -d macos           # macOS

# 代码质量
dart analyze --fatal-infos --fatal-warnings  # 静态分析
flutter test                   # 运行测试
dart format lib/               # 格式化代码

# 构建
flutter build apk --release
flutter build ios --release
flutter build web --release

# 清理
flutter clean
```

## 测试指南

- 使用 `flutter test` 进行单元/组件测试
- 测试文件放在 `test/` 目录下，镜像源码路径
- 测试命名：`feature_name_behavior_test.dart`
- 添加逻辑时包含回归测试

## 提交与 PR 指南

- 提交信息：简洁的祈使句总结（如 `Add matching refill flow`）
- PR：包含变更描述、验证步骤、UI 变更截图
- 确保 `dart analyze` 和 `flutter test` 通过

## 关键约束总结

1. **禁止硬编码字符串** - 所有用户可见文本必须使用 `AppLocalizations`
2. **禁止使用 print()** - 必须使用 `logger` 包
3. **禁止 Repository 返回 Map** - 必须返回 Model 对象
4. **禁止 View 直接访问数据库** - 必须通过 Repository → Controller → View
5. **禁止可变 State** - 所有 State 类必须不可变并提供 `copyWith()`
6. **必须实现 fromMap/toMap** - 所有 Model 类必须实现这两个方法
7. **数据库列名转换** - snake_case (DB) ↔ camelCase (Dart)
