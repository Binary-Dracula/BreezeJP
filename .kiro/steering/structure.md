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
│   ├── algorithm/           # SRS 算法实现
│   │   ├── algorithm_service.dart          # 算法服务接口
│   │   ├── algorithm_service_provider.dart # Riverpod Provider
│   │   ├── sm2_algorithm.dart              # SM-2 算法实现
│   │   ├── fsrs_algorithm.dart             # FSRS 算法实现
│   │   └── srs_types.dart                  # SRS 类型定义
│   ├── constants/           # 全局常量
│   │   └── app_constants.dart              # 应用常量定义
│   ├── network/             # 网络层
│   │   ├── dio_client.dart                 # HTTP 客户端封装
│   │   ├── api_endpoints.dart              # API 端点定义
│   │   └── network_info.dart               # 网络状态检查
│   ├── utils/               # 工具类
│   │   ├── app_logger.dart                 # 日志工具主入口
│   │   ├── log_category.dart               # 日志分类定义
│   │   ├── log_formatter.dart              # 日志格式化器
│   │   ├── l10n_utils.dart                 # 国际化工具
│   │   ├── LOGGER_QUICK_REF.md            # 日志使用快速参考
│   │   └── README.md                       # 工具类说明文档
│   └── widgets/             # 可复用 UI 组件
│       ├── custom_ruby_text.dart          # 自定义假名注音组件
│       └── stroke_order_animator.dart     # 笔顺动画组件
├── data/                    # 数据层
│   ├── db/                  # 数据库层
│   │   └── app_database.dart               # 数据库单例管理
│   ├── models/              # 数据模型 (fromMap/toMap)
│   │   ├── app_state.dart                  # 应用状态模型
│   │   ├── user.dart                       # 用户模型
│   │   ├── daily_stat.dart                 # 每日统计模型
│   │   ├── word.dart                       # 单词基础模型
│   │   ├── word_detail.dart                # 单词详情模型
│   │   ├── word_meaning.dart               # 单词释义模型
│   │   ├── word_audio.dart                 # 单词音频模型
│   │   ├── word_choice.dart                # 单词选择模型
│   │   ├── word_with_relation.dart         # 带关联的单词模型
│   │   ├── example_sentence.dart           # 例句模型
│   │   ├── example_audio.dart              # 例句音频模型
│   │   ├── study_word.dart                 # 学习进度模型
│   │   ├── study_log.dart                  # 学习日志模型
│   │   ├── kana_letter.dart                # 假名字母模型
│   │   ├── kana_detail.dart                # 假名详情模型
│   │   ├── kana_audio.dart                 # 假名音频模型
│   │   ├── kana_example.dart               # 假名示例模型
│   │   ├── kana_learning_state.dart        # 假名学习状态模型
│   │   ├── kana_log.dart                   # 假名学习日志模型
│   │   └── kana_stroke_order.dart          # 假名笔顺模型
│   └── repositories/        # 数据仓库层 (CRUD + Providers)
│       ├── active_user_provider.dart       # 当前用户 Provider
│       ├── app_state_repository.dart       # 应用状态仓库
│       ├── app_state_repository_provider.dart
│       ├── user_repository.dart            # 用户数据仓库
│       ├── user_repository_provider.dart
│       ├── daily_stat_repository.dart      # 每日统计仓库
│       ├── daily_stat_repository_provider.dart
│       ├── word_repository.dart            # 单词数据仓库
│       ├── word_repository_provider.dart
│       ├── study_word_repository.dart      # 学习进度仓库
│       ├── study_word_repository_provider.dart
│       ├── study_log_repository.dart       # 学习日志仓库
│       ├── study_log_repository_provider.dart
│       ├── kana_repository.dart            # 假名数据仓库
│       ├── kana_repository_provider.dart
│       └── example_api_repository.dart     # 例句 API 仓库
├── debug/                   # 调试工具 (仅开发环境)
│   ├── controller/          # 调试控制器
│   │   └── debug_controller.dart
│   ├── pages/               # 调试页面
│   │   ├── debug_page.dart                 # 调试主页面
│   │   └── tests/                          # 调试测试页面
│   ├── state/               # 调试状态
│   │   └── debug_state.dart
│   ├── tools/               # 调试工具
│   │   └── debug_kana_review_data_generator.dart
│   └── widgets/             # 调试组件
│       └── debug_test_tile.dart
├── features/                # 功能模块 (MVVM 架构)
│   ├── splash/              # ✅ 启动页面
│   │   ├── controller/      # 启动逻辑控制器
│   │   ├── pages/           # 启动页面 UI
│   │   └── state/           # 启动状态管理
│   ├── home/                # ✅ 首页 Dashboard
│   │   ├── controller/      # 主页业务逻辑
│   │   │   └── home_controller.dart
│   │   ├── pages/           # 主页 UI 实现
│   │   │   └── home_page.dart
│   │   └── state/           # 主页状态定义
│   │       └── home_state.dart
│   ├── learn/               # ✅ 单词学习流
│   │   ├── controller/      # 学习逻辑控制器
│   │   ├── pages/           # 学习页面 UI
│   │   ├── state/           # 学习状态管理
│   │   └── widgets/         # 学习专用组件
│   └── kana/                # 🚧 假名学习模块
│       ├── chart/           # 五十音图功能
│       ├── review/          # 假名复习功能
│       └── stroke/          # 笔顺练习功能
├── l10n/                    # 国际化支持
│   ├── app_localizations.dart              # 国际化主文件
│   ├── app_localizations_zh.dart           # 中文本地化
│   └── app_zh.arb                          # 中文资源文件
├── router/                  # 路由管理
│   ├── app_router.dart                     # 路由配置
│   └── app_route_observer.dart             # 路由观察器
├── services/                # 横切服务
│   ├── audio_service.dart                  # 音频服务接口
│   ├── audio_service_provider.dart         # 音频服务 Provider
│   ├── audio_play_controller.dart          # 音频播放控制器
│   ├── audio_play_controller_provider.dart # 播放控制器 Provider
│   ├── audio_play_state.dart               # 音频播放状态
│   └── README.md                           # 服务层说明文档
└── main.dart                # 应用入口文件
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
