---
inclusion: always
---

---

## inclusion: always

# 技术栈与开发规范

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

## 命名规范

### 文件命名

| 类型       | 格式           | 示例                                        |
| ---------- | -------------- | ------------------------------------------- |
| 文件名     | snake_case     | `app_database.dart`, `word_repository.dart` |
| 类名       | PascalCase     | `AppDatabase`, `WordRepository`             |
| 变量/函数  | camelCase      | `wordId`, `getUserById()`                   |
| 数据库列名 | snake_case     | `word_id`, `jlpt_level`, `created_at`       |
| 常量       | lowerCamelCase | `defaultEaseFactor`, `maxRetryCount`        |

### Feature 模块文件结构

```
lib/features/{feature_name}/
├── controller/{feature}_controller.dart
├── state/{feature}_state.dart
├── pages/{feature}_page.dart
└── widgets/{component}_widget.dart (可选)
```

### 数据层文件命名

- Model: `lib/data/models/{entity}.dart` (如 `word.dart`)
- Repository: `lib/data/repositories/{entity}_repository.dart`
- Provider: `lib/data/repositories/{entity}_repository_provider.dart`

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

**添加新文本**：

1. 在 `lib/l10n/app_zh.arb` 添加键值对：`"startButton": "开始学习"`
2. 保存后自动生成代码
3. 使用：`l10n.startButton`

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

**日志内容要求**：

- 使用中文描述业务逻辑
- 关键变量使用英文命名并附带值
- 异常日志必须包含 `error` 和 `stackTrace`
- 避免在循环中输出大量日志

### 3. 数据模型规范

**所有 Model 类必须实现 `fromMap()` 和 `toMap()`**

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

**时间戳处理**：

```dart
// 数据库存储 Unix 时间戳（秒），Dart 使用毫秒
// 读取
final timestamp = map['created_at'] as int;
final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

// 写入
final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
```

### 4. Riverpod 状态管理

**Provider 定义**：

```dart
final myControllerProvider = NotifierProvider<MyController, MyState>(
  MyController.new,
);
```

**Controller（业务逻辑）**：

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

**State（不可变数据）**：

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

**View（UI）**：

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

**规则**：

- `ref.watch()` - 订阅状态变化（触发重建）
- `ref.read()` - 一次性读取或调用方法（不触发重建）
- State 类必须不可变并提供 `copyWith()`

### 5. Repository 模式

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

### 6. UI 开发规范

- 日文文本使用 `ruby_text` 包显示假名注音
- 例句高亮使用 `<b>` 标签，View 层解析显示
- 音频播放通过 `AudioService` 封装，不在 Repository 中处理
- 遵循 `flutter_lints` 规则
- 使用 `dart format` 格式化代码
- 代码注释使用中文

### 7. 路由导航

```dart
context.go('/home');                          // 导航到路由
context.go('/word-detail', extra: wordId);    // 传递参数
context.pop();                                // 返回
context.replace('/login');                    // 替换当前路由
```

## 常用命令

```bash
# 依赖管理
flutter pub get
flutter pub upgrade

# 运行
flutter run                    # 默认设备
flutter run -d chrome          # Web
flutter run -d macos           # macOS

# 代码生成
flutter pub run build_runner build
flutter pub run build_runner build --delete-conflicting-outputs

# 代码质量
flutter analyze                # 静态分析
flutter test                   # 运行测试
dart format lib/               # 格式化代码

# 构建
flutter build apk --release
flutter build ios --release
flutter build web --release

# 清理
flutter clean
```

## 数据库配置

- 预置数据库路径：`assets/database/breeze_jp.sqlite`
- 首次启动时从 assets 复制到应用文档目录
- 访问方式：`AppDatabase.instance`（单例模式）
- 获取当前用户：查询 `app_state` 表的 `current_user_id` 字段

## 关键约束总结

1. **禁止硬编码字符串** - 所有用户可见文本必须使用 `AppLocalizations`
2. **禁止使用 print()** - 必须使用 `logger` 包
3. **禁止 Repository 返回 Map** - 必须返回 Model 对象
4. **禁止 View 直接访问数据库** - 必须通过 Repository → Controller → View
5. **禁止可变 State** - 所有 State 类必须不可变并提供 `copyWith()`
6. **必须实现 fromMap/toMap** - 所有 Model 类必须实现这两个方法
7. **数据库列名转换** - snake_case (DB) ↔ camelCase (Dart)
