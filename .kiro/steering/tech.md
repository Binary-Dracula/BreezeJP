---
inclusion: always
---

# 技术栈与开发规范

## 技术栈

**Flutter 3.38.1** (Dart SDK ^3.10.0) - 跨平台移动应用

### 核心依赖

| 类别     | 包名                      | 用途                                                                  |
| -------- | ------------------------- | --------------------------------------------------------------------- |
| 状态管理 | flutter_riverpod ^3.0.3   | MVVM 状态管理（使用 `NotifierProvider`）                              |
| 数据库   | sqflite ^2.3.3            | SQLite 本地数据库（Data 层通过 `AppDatabase.instance`/Provider 访问） |
| 路由     | go_router ^17.0.0         | 声明式路由（`context.go()`, `context.pop()`）                         |
| 音频     | just_audio ^0.10.5        | 音频播放（通过 `AudioService` 封装）                                  |
| UI       | ruby_text ^3.0.3          | 日文假名注音渲染                                                      |
| 动画     | flutter_animate ^4.5.0    | 声明式动画                                                            |
| 手势     | gesture_x_detector ^1.1.1 | 高级手势识别                                                          |
| 工具     | kana_kit ^2.1.1           | 假名/罗马音转换                                                       |
| 网络     | dio ^5.7.0                | HTTP 客户端                                                           |
| 日志     | logger ^2.5.0             | 日志输出（通过 `lib/core/utils/app_logger.dart`）                     |
| 国际化   | intl ^0.20.2              | 多语言支持（`AppLocalizations`）                                      |

## 架构模式

**MVVM + Command/Query/Analytics/Repository + Session + Riverpod**

```
View → Controller
           ├─→ Query (Read)
           ├─→ Analytics (Statistics)
           └─→ Command (Behavior / Write)
                       ↓
                 Repository (Entity CRUD)
                       ↓
                    Database
```

### 层级职责与约束

| 层级                | 职责                                               | 禁止事项                               |
| ------------------- | -------------------------------------------------- | -------------------------------------- |
| **View**            | UI 渲染、用户交互                                  | 直接访问数据库、业务逻辑、修改 state   |
| **Controller**      | 流程编排、调用 Command/Query/Analytics、管理 State | 直接 DB 查询、直接调用 Repository      |
| **Command**         | 写行为、状态变更、副作用入口                       | 返回 Map、直接 SQL 拼接                |
| **Command/Session** | 学习/复习流程编排、统计聚合入口                    | 绕过 Session 写 daily_stats/study_logs |
| **Query**           | 只读查询（join / filter / paging / 列表 / 详情）   | 写操作                                 |
| **Analytics**       | 统计聚合 / 报表 / 计数                             | 写操作                                 |
| **Repository**      | Entity CRUD（单表/强一致实体）                     | join / 统计 / 业务语义 / 暴露 Database |
| **External**        | 外部 API Client（HTTP/SDK 适配）                   | 本地持久化或业务语义                   |
| **Model**           | 数据结构，含 `fromMap()`/`toMap()`                 | 业务逻辑                               |
| **State**           | 不可变数据容器                                     | 可变字段、逻辑                         |

**关键规则**：

- Controller 仅调用 Command / Query / Analytics
- Repository 只做 CRUD，不能包含 join/统计/业务语义
- Query / Analytics 只读，使用 `databaseProvider` 注入 Database
- Command 不返回 Map 或 SQL 原始结果
- Session 是统计唯一入口：`SessionStatPolicy → accumulator → flush → DailyStatCommand.applySession`
- External Client 不属于 Repository，不纳入 Repository 纯度规则

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

- Model: `lib/data/models/{entity}.dart`
- Read DTO: `lib/data/models/read/{dto}.dart`
- Repository: `lib/data/repositories/{entity}_repository.dart`
- Query: `lib/data/queries/{entity}_query.dart`
- Analytics: `lib/data/analytics/{entity}_analytics.dart`
- Command: `lib/data/commands/{entity}_command.dart`
- External Client: `lib/data/external/{name}_client.dart`

## 国际化（i18n）

**⚠️ 所有用户可见文本必须使用 `AppLocalizations`，严禁硬编码字符串**

```dart
// ✅ 正确
final l10n = AppLocalizations.of(context)!;
Text(l10n.startLearning);
Button(onPressed: () {}, child: Text(l10n.cancelButton));

// ❌ 错误
Text('开始学习');
Button(onPressed: () {}, child: Text('取消'));
```

## 日志规范

**使用 `logger` 包，禁止使用 `print()`**

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';

logger.i('用户开始学习 Session');
logger.d('加载单词详情: wordId=$wordId');
logger.w('音频文件不存在: $audioPath');
logger.e('数据库查询失败', error: e, stackTrace: stackTrace);
```

## 数据模型规范

**所有 Model 类必须实现 `fromMap()` 和 `toMap()`**

```dart
class Word {
  final int id;
  final String word;
  final String? furigana;
  final String? jlptLevel;

  Word({required this.id, required this.word, this.furigana, this.jlptLevel});

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int,
      word: map['word'] as String,
      furigana: map['furigana'] as String?,
      jlptLevel: map['jlpt_level'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'furigana': furigana,
      'jlpt_level': jlptLevel,
    };
  }
}
```

**时间戳处理**：

```dart
final timestamp = map['created_at'] as int;
final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

final nowSeconds = (DateTime.now().millisecondsSinceEpoch / 1000).round();
```

## Riverpod 状态管理

**Provider 定义**：

```dart
final myControllerProvider = NotifierProvider<MyController, MyState>(
  MyController.new,
);
```

**Controller（流程编排）**：

```dart
class MyController extends Notifier<MyState> {
  @override
  MyState build() => const MyState();

  Future<void> loadData() async {
    final query = ref.read(wordReadQueriesProvider);
    final words = await query.getRandomWords(limit: 10);
    state = state.copyWith(words: words);
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
    final state = ref.watch(myControllerProvider);
    final controller = ref.read(myControllerProvider.notifier);

    return Scaffold(
      body: state.isLoading
          ? const CircularProgressIndicator()
          : ListView(...),
    );
  }
}
```

## Repository / Query / Analytics 示例

**Repository（CRUD only）**：

```dart
class WordRepository {
  Future<Word?> getWordById(int id) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Word.fromMap(results.first);
  }
}
```

**Query（只读）**：

```dart
class WordReadQueries {
  WordReadQueries(this._db);
  final Database _db;

  Future<List<Word>> getRandomWords({int limit = 10}) async {
    final results = await _db.rawQuery(
      'SELECT * FROM words ORDER BY RANDOM() LIMIT ?',
      [limit],
    );
    return results.map((row) => Word.fromMap(row)).toList();
  }
}
```

## UI 开发规范

- 日文文本使用 `ruby_text` 包显示假名注音
- 例句高亮使用 `<b>` 标签，View 层解析显示
- 音频播放通过 `AudioService` 封装，不在 Repository 中处理
- 遵循 `flutter_lints` 规则
- 使用 `dart format` 格式化代码

## 路由导航

```dart
context.go('/home');
context.go('/word-detail', extra: wordId);
context.pop();
context.replace('/login');
```

## 常用命令

```bash
flutter pub get
flutter pub upgrade
flutter run
flutter run -d chrome
flutter run -d macos
flutter analyze
flutter test
dart format lib/
flutter build apk --release
flutter build ios --release
flutter build web --release
flutter clean
```

## 数据库配置

- 预置数据库路径：`assets/database/breeze_jp.sqlite`
- Database 生命周期由 `lib/data/db/` 管理
- Repository 使用 `AppDatabase.instance`，Query/Analytics 使用 `databaseProvider`
- 当前用户由 `ActiveUserCommand` / `ActiveUserQuery` 读写

## 关键约束总结

1. **禁止硬编码字符串** - 所有用户可见文本必须使用 `AppLocalizations`
2. **禁止使用 print()** - 必须使用 `logger`
3. **禁止 Repository 返回 Map** - 必须返回 Model
4. **禁止 Controller 直接访问 Repository/Database** - 仅调用 Command / Query / Analytics
5. **禁止 Query/Analytics 写操作** - 只读
6. **Command 为唯一写入口** - 不返回 Map 或 SQL 原始结果
7. **Session 为统计唯一入口** - `applySession` 写入 daily_stats
