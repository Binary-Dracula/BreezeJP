---
inclusion: always
---

# 项目架构与文件组织

## 架构模式：MVVM + Repository + Riverpod

**数据流：**
```
View（UI） ↔ Controller（业务逻辑） ↔ Repository（CRUD） ↔ Database
                  ↕
                State（不可变数据）
```

**各层职责：**

| Layer | 职责 | 禁止 |
|-------|------|------|
| **View** | UI 渲染、用户交互 | 直接访问数据库、业务逻辑、修改 state |
| **Controller** | 业务逻辑、状态管理 | 数据加工、直接 DB 查询 |
| **State** | 不可变数据容器 | 可变字段、逻辑 |
| **Repository** | CRUD、DB 查询 | 业务逻辑、UI 相关 |
| **Model** | 数据结构，含 `fromMap()`/`toMap()` | 业务逻辑 |

**硬性规则：**
- 数据访问仅限：Repository → Controller → View
- Repository 只返回模型对象，绝不返回 Map
- 所有 State 必须不可变并提供 `copyWith()`
- 所有 DB 访问必须用 `AppDatabase.instance` 单例

## 目录结构

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
```

**Assets：**
```
assets/
├── audio/
│   ├── words/               # 单词发音
│   ├── examples/            # 例句音频
│   └── kana/                # 假名发音
├── database/
│   └── breeze_jp.sqlite     # 预置 SQLite
└── images/
```

## 文件命名与放置

### Feature 模块 (`lib/features/[feature_name]/`)

**标准结构：**
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

### 数据层

**Models** (`lib/data/models/`):
- 文件：`[entity].dart`（如 `word.dart`、`study_word.dart`）
- 必须实现：`fromMap(Map<String, dynamic>)` 与 `toMap()`
- 命名：DB snake_case → Dart camelCase

**Repositories** (`lib/data/repositories/`):
- 文件：`[entity]_repository.dart`
- Provider：`[entity]_repository_provider.dart`
- 返回模型对象，使用 `AppDatabase.instance`
- 只做 CRUD，不写业务逻辑

### 共享代码

**Widgets** (`lib/core/widgets/`):
- 文件：`[widget_name].dart`
- 尽量无状态，跨 Feature 复用

**Utils** (`lib/core/utils/`):
- 文件：`[function]_utils.dart`
- 纯函数，无状态

**Services** (`lib/services/`):
- 文件：`[service]_service.dart`
- Provider：`[service]_service_provider.dart`
- 横切能力（音频、网络等）

## Riverpod 状态管理

**Provider 定义：**
```dart
final myControllerProvider =
    NotifierProvider<MyController, MyState>(MyController.new);
```

**Controller（业务逻辑）：**
```dart
class MyController extends Notifier<MyState> {
  @override
  MyState build() => const MyState();

  Future<void> loadData() async {
    final repo = ref.read(myRepositoryProvider);
    final data = await repo.getData();
    state = state.copyWith(data: data); // 不可变更新
  }
}
```

**State（不可变数据）：**
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

**View（UI）：**
```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);      // 订阅状态
    final controller = ref.read(myControllerProvider.notifier); // 调用方法

    return Scaffold(
      body: state.isLoading ? const CircularProgressIndicator() : ListView(...),
    );
  }
}
```

**使用规则：**
- `ref.watch()`：订阅并重建
- `ref.read()`：一次性读取/调用方法
- State 必须不可变，提供 `copyWith()`
- 每个 Feature 拥有独立 Provider

## 数据库访问

**Repository 模式（必选）：**

```dart
class WordRepository {
  Future<List<Word>> getWordsByLevel(String level) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query(
      'words',
      where: 'jlpt_level = ?',
      whereArgs: [level],
    );
    return results.map((m) => Word.fromMap(m)).toList(); // Map → Model
  }

  Future<void> updateWord(Word word) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }
}
```

**规则：**
- ✅ 访问路径：Repository → Controller → View
- ❌ 禁止 Controller/View 直接查 DB
- ✅ 只返回模型对象
- ✅ 统一使用 `AppDatabase.instance`
- ✅ 异常在 Repository 层处理

## 路由（go_router）

```dart
context.go('/home');                          // 跳转
context.go('/word-detail', extra: wordId);    // 传参
context.pop();                                // 返回
context.replace('/login');                    // 替换当前路由
```

## 国际化（i18n）

**⚠️ 所有用户可见文本必须通过 AppLocalizations，禁止硬编码。**

**正确：**
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.startLearning);
```

**错误：**
```dart
Text('开始学习');  // ❌ 硬编码
```

**新增文案流程：**
1. 添加到 `lib/l10n/app_zh.arb`，如 `"startButton": "开始学习"`
2. 保存生成代码
3. 使用 `l10n.startButton`

**命名规范：**

| 类型 | 格式 | 示例 |
|------|------|------|
| 按钮 | `{action}Button` | `startButton`、`cancelButton` |
| 标题 | `{page}Title` | `homeTitle`、`settingsTitle` |
| 提示 | `{context}Hint` | `searchHint`、`emptyHint` |
| 错误 | `{context}Error` | `networkError`、`loadError` |
| 标签 | `{context}Label` | `levelLabel`、`countLabel` |

## 日志规范

### 日志工具
统一使用 `lib/core/utils/app_logger.dart` 封装的 `logger`。

### 日志级别

| 级别 | 场景 | 方法 |
|------|------|------|
| Trace | 细粒度调试 | `logger.t()` |
| Debug | 调试信息 | `logger.d()` |
| Info | 关键流程节点 | `logger.i()` |
| Warning | 可恢复异常 | `logger.w()` |
| Error | 需关注的错误 | `logger.e()` |
| Fatal | 崩溃级错误 | `logger.f()` |

### 书写示例

```dart
// ✅ 推荐
logger.i('用户开始学习 Session');
logger.d('加载单词详情: wordId=$wordId');
logger.w('音频文件不存在: $audioPath');
logger.e('数据库查询失败', error: e, stackTrace: stackTrace);

// ❌ 禁止
print('调试日志');
```

### 内容要求
- 业务描述用中文，变量英文
- 异常必须包含 `error` 和 `stackTrace`
- 避免循环打印大量日志

### 关键日志点

| 场景 | 级别 | 示例 |
|------|------|------|
| 应用启动 | Info | `logger.i('应用启动完成')` |
| 数据库初始化 | Info | `logger.i('数据库初始化成功')` |
| 用户操作 | Info | `logger.i('用户点击开始学习')` |
| 数据加载 | Debug | `logger.d('加载待复习单词: count=$count')` |
| 算法计算 | Debug | `logger.d('SM-2 计算结果: interval=$interval')` |
| 网络请求 | Debug | `logger.d('API 请求: $url')` |
| 文件操作 | Warning | `logger.w('音频文件缺失: $filename')` |
| 异常捕获 | Error | `logger.e('Repository 操作失败', error: e)` |
| 崩溃级错误 | Fatal | `logger.f('数据库损坏无法恢复', error: e)` |

### 生产环境

```dart
void main() {
  if (kReleaseMode) {
    Logger.level = Level.warning; // Release 仅 Warning+
  }
  runApp(const MyApp());
}
```
