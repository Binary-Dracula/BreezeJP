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
│   │   └── l10n_utils.dart
│   └── widgets/             # 可复用 UI 组件
│       └── custom_ruby_text.dart
├── data/                    # 数据层
│   ├── db/
│   │   └── app_database.dart
│   ├── models/
│   │   ├── word.dart
│   │   ├── word_meaning.dart
│   │   ├── word_audio.dart
│   │   ├── word_detail.dart
│   │   ├── example_sentence.dart
│   │   ├── example_audio.dart
│   │   ├── study_word.dart
│   │   ├── study_log.dart
│   │   ├── daily_stat.dart
│   │   └── user.dart
│   └── repositories/
│       ├── word_repository.dart
│       ├── study_word_repository.dart
│       ├── study_log_repository.dart
│       ├── daily_stat_repository.dart
│       ├── user_repository.dart
│       └── example_api_repository.dart
├── features/                # 功能模块
│   ├── splash/              # 启动页面 ✅
│   ├── home/                # 首页 ✅
│   ├── learn/               # 学习功能 🚧
│   ├── review/              # 复习功能 📋
│   ├── word_detail/         # 单词详情 🚧
│   ├── word_list/           # 单词列表 🚧
│   └── settings/            # 设置 📋
├── l10n/                    # 国际化
│   ├── app_zh.arb
│   ├── app_localizations.dart
│   └── app_localizations_zh.dart
├── router/
│   └── app_router.dart
├── services/
│   ├── audio_service.dart
│   └── audio_service_provider.dart
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
│   └── examples/   # 例句音频
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

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.appName);
```

添加翻译：在 `app_zh.arb` 添加键值对，保存后自动生成代码
