---
inclusion: always
---

# 项目架构与文件组织

## 目录结构

```
lib/
├── core/                    # 共享层
│   ├── algorithm/           # SRS 算法实现
│   │   ├── algorithm_service.dart
│   │   ├── algorithm_service_provider.dart
│   │   ├── sm2_algorithm.dart
│   │   ├── fsrs_algorithm.dart
│   │   └── srs_types.dart
│   ├── constants/           # 应用级常量
│   │   └── app_constants.dart
│   ├── network/             # 网络层
│   │   ├── dio_client.dart
│   │   ├── api_endpoints.dart
│   │   └── network_info.dart
│   ├── utils/               # 工具函数
│   │   ├── app_logger.dart
│   │   ├── l10n_utils.dart
│   │   ├── log_category.dart
│   │   └── log_formatter.dart
│   └── widgets/             # 可复用 UI 组件
│       ├── custom_ruby_text.dart
│       └── stroke_order_animator.dart
├── data/                    # 数据层
│   ├── db/
│   │   └── app_database.dart
│   ├── models/
│   │   ├── app_state.dart             # 应用状态
│   │   ├── word.dart
│   │   ├── word_meaning.dart
│   │   ├── word_audio.dart
│   │   ├── word_detail.dart
│   │   ├── word_choice.dart           # 单词选择
│   │   ├── word_with_relation.dart    # 带关联的单词
│   │   ├── example_sentence.dart
│   │   ├── example_audio.dart
│   │   ├── study_word.dart
│   │   ├── study_log.dart
│   │   ├── daily_stat.dart
│   │   ├── user.dart
│   │   ├── kana_letter.dart           # 五十音字母
│   │   ├── kana_audio.dart            # 五十音音频
│   │   ├── kana_example.dart          # 五十音示例
│   │   ├── kana_learning_state.dart   # 五十音学习状态
│   │   ├── kana_log.dart              # 五十音学习日志
│   │   ├── kana_detail.dart           # 五十音详情
│   │   └── kana_stroke_order.dart     # 五十音笔顺
│   └── repositories/
│       ├── word_repository.dart
│       ├── word_repository_provider.dart
│       ├── study_word_repository.dart
│       ├── study_word_repository_provider.dart
│       ├── study_log_repository.dart
│       ├── study_log_repository_provider.dart
│       ├── daily_stat_repository.dart
│       ├── daily_stat_repository_provider.dart
│       ├── user_repository.dart
│       ├── user_repository_provider.dart
│       ├── app_state_repository.dart
│       ├── app_state_repository_provider.dart
│       ├── active_user_provider.dart  # 当前活跃用户 Provider
│       ├── example_api_repository.dart
│       ├── kana_repository.dart
│       └── kana_repository_provider.dart
├── features/                # 功能模块
│   ├── splash/              # 启动页面 ✅
│   │   ├── controller/
│   │   ├── pages/
│   │   └── state/
│   ├── home/                # 首页 ✅
│   │   ├── controller/
│   │   ├── pages/
│   │   └── state/
│   ├── learn/               # 学习功能 ✅
│   │   ├── controller/
│   │   ├── pages/
│   │   ├── state/
│   │   └── widgets/
│   ├── kana/                # 五十音图学习 🚧
│   │   ├── controller/
│   │   ├── pages/
│   │   ├── state/
│   │   └── widgets/
│   ├── review/              # 复习功能 📋
│   ├── word_detail/         # 单词详情 📋
│   ├── word_list/           # 单词列表 📋
│   └── settings/            # 设置 📋
├── l10n/                    # 国际化
│   ├── app_zh.arb
│   ├── app_localizations.dart
│   └── app_localizations_zh.dart
├── router/
│   └── app_router.dart
├── services/
│   ├── audio_service.dart
│   ├── audio_service_provider.dart
│   ├── audio_play_controller.dart
│   ├── audio_play_controller_provider.dart
│   └── audio_play_state.dart
└── main.dart
```

## 功能模块结构

```
features/[功能名]/
├── controller/    # Riverpod 控制器
├── pages/         # 页面组件
├── state/         # 状态类
└── widgets/       # 功能内组件（可选）
```

## 文件放置规则

### 数据模型
- 路径：`lib/data/models/`
- 命名：`[实体名].dart`
- 必须实现 `fromMap()` 和 `toMap()`

### Repository
- 路径：`lib/data/repositories/`
- 命名：`[实体名]_repository.dart`
- Provider：`[实体名]_repository_provider.dart`

### 功能模块
- 路径：`lib/features/[功能名]/`
- Controller：`[功能名]_controller.dart`
- State：`[功能名]_state.dart`
- Page：`[功能名]_page.dart`

### 共享组件
- 路径：`lib/core/widgets/`
- 命名：`[组件名].dart`

### 工具函数
- 路径：`lib/core/utils/`
- 命名：`[功能名]_utils.dart`

### 服务
- 路径：`lib/services/`
- 命名：`[服务名]_service.dart`
- Provider：`[服务名]_service_provider.dart`

## 资源文件

```
assets/
├── audio/
│   ├── words/      # 单词音频
│   ├── examples/   # 例句音频
│   └── kana/       # 五十音音频
├── database/
│   └── breeze_jp.sqlite
└── images/
```

## 状态管理模式

```dart
// Provider 定义
final myControllerProvider = 
    NotifierProvider<MyController, MyState>(MyController.new);

// Controller
class MyController extends Notifier<MyState> {
  @override
  MyState build() => const MyState();
  
  Future<void> loadData() async { ... }
}

// UI 使用
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myControllerProvider);
    return Scaffold(...);
  }
}
```

## 数据库访问

```dart
// 通过 Repository（推荐）
class WordRepository {
  Future<List<Word>> getWordsByLevel(String level) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query('words', where: 'jlpt_level = ?', whereArgs: [level]);
    return results.map((map) => Word.fromMap(map)).toList();
  }
}
```

## 路由导航

```dart
context.go('/home');           // 跳转
context.go('/word-detail', extra: wordId);  // 带参数
context.pop();                 // 返回
```

## 国际化

**⚠️ 重要：所有用户可见的文本必须使用国际化，禁止硬编码字符串**

```dart
// ✅ 正确：使用国际化
final l10n = AppLocalizations.of(context)!;
Text(l10n.appName);
Text(l10n.startLearning);

// ❌ 错误：硬编码字符串
Text('开始学习');
Text('BreezeJP');
```

### 添加新文本

1. 在 `lib/l10n/app_zh.arb` 添加键值对
2. 保存后自动生成代码
3. 使用 `l10n.keyName` 引用

### 命名规范

| 类型 | 命名格式 | 示例 |
|------|----------|------|
| 按钮文本 | `{action}Button` | `startButton`, `cancelButton` |
| 标题 | `{page}Title` | `homeTitle`, `settingsTitle` |
| 提示信息 | `{context}Hint` | `searchHint`, `emptyHint` |
| 错误信息 | `{context}Error` | `networkError`, `loadError` |
| 标签 | `{context}Label` | `levelLabel`, `countLabel` |

## Log 日志规则

### 日志工具

使用 `logger` 包进行日志输出，统一通过 `lib/core/utils/app_logger.dart` 管理。

### 日志级别

| 级别 | 使用场景 | 方法 |
|------|----------|------|
| Trace | 详细的调试信息（开发阶段） | `logger.t()` |
| Debug | 调试信息（开发阶段） | `logger.d()` |
| Info | 一般信息（关键流程节点） | `logger.i()` |
| Warning | 警告信息（可恢复的异常） | `logger.w()` |
| Error | 错误信息（需要关注的异常） | `logger.e()` |
| Fatal | 致命错误（应用崩溃级别） | `logger.f()` |

### 日志规范

```dart
// ✅ 推荐：使用 logger
import 'package:breeze_jp/core/utils/app_logger.dart';

logger.i('用户开始学习 Session');
logger.d('加载单词详情: wordId=$wordId');
logger.w('音频文件不存在: $audioPath');
logger.e('数据库查询失败', error: e, stackTrace: stackTrace);

// ❌ 禁止：使用 print()
print('这是不规范的日志');
```

### 日志内容要求

- 使用中文描述业务逻辑
- 关键变量使用英文命名并附带值
- 异常日志必须包含 `error` 和 `stackTrace`
- 避免在循环中输出大量日志

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

### 生产环境配置

在 `main.dart` 中根据编译模式调整日志级别：

```dart
void main() {
  // Release 模式下仅输出 Warning 及以上级别
  if (kReleaseMode) {
    Logger.level = Level.warning;
  }
  runApp(const MyApp());
}
```
