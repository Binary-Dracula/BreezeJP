---
applyTo: "**"
description: BreezeJP 工程级架构规范与编码准则，适用于全项目所有代码。适用于 Agent 和开发者在进行任何编码、修改、扩展时作为权威参考。
---

# BreezeJP 工程架构规范

> **本文档是 BreezeJP 项目的权威工程准则，完全自包含。** Agent 或开发者在进行任何编码时必须遵守。

## 0. 规则入口

- `.github/README.md` 是当前仓库的开发规则导航页。
- `.github/coding_rules.instructions.md` 是全项目默认生效的工程规则入口。
- `.github/` 下的其他专题文档用于补充长期有效的专项规约；若与历史散落文档冲突，以 `.github/` 下文档为准。

---

## 1. 语言偏好

- 无论情况如何，使用**简体中文**回答用户所有问题及进行交流。
- 文档、计划、报告、代码注释均用**简体中文**撰写。
- Skill 元数据命名约束：`SKILL.md` frontmatter 的 `name` 必须仅包含小写字母、数字、连字符（`-`），且必须与其所在技能目录名完全一致。

---

## 2. 技术栈

| 维度      | 版本/工具/规范                     |
| --------- | ---------------------------------- |
| Framework | Flutter 3.38.1 (Dart SDK ^3.10.0)  |
| 状态管理  | `flutter_riverpod ^3.0.3`          |
| 路由      | `go_router ^17.0.0`                |
| 数据库    | SQLite via `sqflite`               |
| 网络      | Dio                                |
| 国际化    | `flutter_localizations` (intl)     |
| 音频      | `just_audio` + `record`            |
| 数据文件  | `assets/database/breeze_jp.sqlite` |
| ARB 模板  | `lib/l10n/app_zh.arb`              |
| 生成命令  | `flutter gen-l10n`                 |

---

## UI 规范入口（轻量提示）

- 当任务涉及 Flutter 页面开发、UI 改版、组件样式、颜色/布局规范时，优先查阅：`.agents/skills/breezejp-ui-design/SKILL.md`。
- 若通用 UI Skill 与项目现有视觉风格冲突，以 BreezeJP UI Skill 为准。

---

## 3. 架构模式

该项目遵循 **MVVM + Command/Query/Analytics/Repository + Session + Riverpod** 模式。

**设计目标**：工程解耦与职责隔离，确保写入口集中、读写分离、统计链路可控。

**依赖流向（单向，禁止反转）**：

```
Feature → Services → Data → Core
```

---

## 4. 目录结构

```
lib/
├── core/               # 核心工具、常量、算法、领域事件
│   ├── domain/         # 领域事件定义 (DomainEventBus, *DomainEvent)
│   ├── algorithm/      # SRS 算法
│   ├── constants/      # 枚举、常量
│   └── utils/          # 工具类（Logger 等）
├── data/               # 数据层
│   ├── commands/       # 写操作 (Command)
│   ├── queries/        # 只读查询 (Query, Analytics)
│   ├── repositories/   # 单表 CRUD (Repository)
│   └── models/         # 数据模型 (Model)
├── features/           # 功能模块（每个 feature 独立目录）
│   └── [feature]/
│       ├── controller/ # 业务逻辑编排 (Controller)
│       ├── pages/      # 页面入口 (*Page)
│       ├── widgets/    # UI 子组件
│       └── state/      # 不可变状态 (*State)
├── services/           # 服务层 (AudioService 等)
├── l10n/               # 国际化 (ARB + Generated)
└── router/             # 集中路由配置 (app_router.dart)
```

---

## 5. 层级职责与强制限制

| 层级           | 工程职责                         | 明确禁止项                                        |
| -------------- | -------------------------------- | ------------------------------------------------- |
| **View**       | UI 渲染、用户交互处理            | 访问 Repository/DB、统计推导、业务状态推导        |
| **Controller** | 编排流程、调度业务、管理 State   | 直接访问 DB 或 Repository                         |
| **Command**    | 唯一写入口、状态变更、触发副作用 | 返回 Map/SQL 原始结构。需实现幂等操作。           |
| **Query**      | 只读查询 (List/Join/Detail)      | 任何写操作（禁止触发写状态）                      |
| **Analytics**  | 聚合统计结果查询（只读）         | 任何写操作                                        |
| **Repository** | 单表 CRUD、一致性保证            | Join 查询、聚合统计、承载业务判断逻辑             |
| **State**      | 不可变状态容器                   | 可变字段（Mutable fields）                        |
| **Router**     | 声明式页面跳转、参数解析传递     | 拦截检查学习状态、推导/计算统计指标               |
| **Debug**      | 调试工具与占位入口               | 直连 Repository 或数据库（即便 Debug 构建也禁止） |

- **Controller 是 Feature 的唯一编排点**
- **Repository 永不暴露给 Feature 层**
- **Command 是所有写操作的唯一入口**

---

## 6. Feature 标准目录结构

每个 Feature 模块遵循以下标准结构：

```
features/[feature]/
├── controller/          # NotifierProvider，唯一编排点
├── pages/               # 页面组件，命名 *Page.dart
├── widgets/             # 子组件
└── state/               # 不可变 State 类
```

**❌ 严格禁止** Feature 内创建 `domain/`、`data/` 子目录。  
**❌ 严格禁止** Feature 内部直接引用 Repository 或数据库。

---

## 7. 路由规则

- 所有路由统一在 `lib/router/app_router.dart` 内定义。
- **必须使用** `context.go()`, `context.push()`, `context.replace()`, `context.pop()`。
- **❌ 禁止** 使用 `Navigator.push()` / `MaterialPageRoute` 等原生 Navigator API。
- **❌ 禁止** 各 Feature 内部私自声明路由。
- **❌ 禁止** 在 Router 中执行业务判断、统计或 Session 调用。
- 页面参数通过 `state.pathParameters` 或 `state.extra` 传递。

---

## 8. 状态管理规则

- Feature Controller 使用 `NotifierProvider`。
- Command / Query / Analytics / Repository 使用 `Provider`。
- 优先使用 `ConsumerWidget` 或 `ConsumerStatefulWidget`。
- `setState` **仅用于纯局部 UI 状态**（如搜索栏显隐、动画标志），不管理任何业务状态。
- **❌ 禁止** 混用 `setState` 和 Riverpod 管理同一业务状态。

---

## 9. 国际化规则

- **所有用户可见文本**必须通过 `AppLocalizations.of(context)!` 提供。
- **❌ 禁止** 硬编码任何用户可见字符串（按钮、标题、提示、占位文字等）。
- ARB 模板文件：`lib/l10n/app_zh.arb`。
- 修改 ARB 后必须运行 `flutter gen-l10n`。
- 生成文件 (`lib/l10n/app_localizations*.dart`) **需提交到仓库**。

---

## 10. 领域事件总线（DomainEventBus）

- 所有领域事件类定义位于 `lib/core/domain/`（如 `kana_domain_event.dart`）。
- 所有 `DomainEvent` 必须是 `sealed class`，子事件为 `final class`。
- 事件通过 `DomainEventBus().publish(event)` 发布。
- 监听器在 `lib/features/[feature]/controller/` 中注册，命名为 `*DomainListener`。

---

## 11. 数据库与模型规范

- SQLite 数据源：`assets/database/breeze_jp.sqlite`。
- Query/Analytics 通过 `databaseProvider` 注入 Database 实例进行操作。
- Repository 内部通过 `AppDatabase.instance` 访问（**不对外暴露**给 Controller/UI）。
- 所有 Model 必须实现 `fromMap(Map<String, dynamic>)` 和 `toMap()`。
- **时间字段**在 DB 中使用**秒级 Unix 时间戳**：
  - 读取：`DateTime.fromMillisecondsSinceEpoch(seconds * 1000)`
  - 写入：`(DateTime.now().millisecondsSinceEpoch / 1000).round()`
- 获取当前用户 ID：必须通过 `ActiveUserQuery`。
- **命名**：DB 列/表名 `snake_case`；Dart Model `PascalCase`，成员 `camelCase`。

---

## 12. 统计口径（冻结，不可修改）

| 指标     | 来源                            | 唯一写入口                            |
| -------- | ------------------------------- | ------------------------------------- |
| 今日学习 | `daily_stats.new_learned_count` | `firstLearn` 事件触发 Command         |
| 今日复习 | `daily_stats.review_count`      | 行为发生时 Command 增量写入           |
| 累计掌握 | 状态表 `mastered` 去重实体数    | 状态变更 Command                      |
| 学习时长 | `daily_stats.total_time_ms`     | `DailyStatCommand.applyTimeOnlyDelta` |

**绝对禁止（统计）：**

- ❌ 从 logs 回放推导统计
- ❌ 从状态表反推事件
- ❌ 混用 state-based 与 event-based 统计
- ❌ 补算 / 修正 / 回填统计

---

## 13. 词汇（Word）学习模型

- **`study_words`**（Status 层）：当前快照状态（`seen`, `learning`, `mastered`, `ignored`）。**状态变化不等于发生了学习事件**。
- **`study_logs`**（Event 层）：行为记录。`firstLearn` 仅产生于用户**第一次点击"加入复习"**，每对 `(user_id, word_id)` **最多一条**。
- **`daily_stats`**（Analytics 层）：今日统计事实，由 Command 写入。

**禁止项：**

- ❌ 从状态变化（`seen → learning`）推导 `firstLearn`
- ❌ 因 `study_words` 不存在而补写 `firstLearn`
- ❌ 从 logs 或状态拼装推算统计供给 UI

---

## 14. 假名（Kana）学习模型

- 纯 **State-based** 设计，使用 `kana_learning_state` 表。
- **不存在** `firstLearn`、`study_logs` 记录，**不影响** `daily_stats`。
- 状态切换：`learning ↔ mastered`。
- 新记录**仅在完整描红后**创建。
- **❌ 禁止** 将假名进度混入词汇统计（Word ↔ Kana 统计严格隔离）。

---

## 15. 语法（Grammar）学习模型

- 三层结构：`grammars` → `grammar_meanings` → `grammar_examples`。
- SRS 控制通过 `study_grammars` 完成。
- **不产生** `study_logs`，**不影响** `daily_stats`。

---

## 16. Word vs Kana 差异对照

| 维度        | Word（单词）  | Kana（假名） |
| ----------- | ------------- | ------------ |
| 数据模型    | Event + State | State only   |
| SRS         | ✅ 独立 SRS   | ✅ 独立 SRS  |
| study_logs  | ✅ 写入       | ❌ 不写      |
| daily_stats | ✅ 影响       | ❌ 不影响    |
| firstLearn  | ✅ 产生       | ❌ 不产生    |

> ❌ **禁止统一 Word 与 Kana 的学习语义**，这是架构破坏。

---

## 17. 学习时长追踪

- 发起源自 `PageDurationTracker`。
- 唯一写入通道：`DailyStatCommand.applyTimeOnlyDelta`。
- **❌ 禁止** 其他路径修改学习时长统计。

---

## 18. 代码风格

- **简洁性**：避免过度工程化，只做必要的抽象。
- **注释**：关键逻辑需有简体中文注释。
- **类型安全**：显式声明类型，减少 `dynamic` 使用。
- **异步**：正确使用 `async/await`，需捕获错误（`try-catch`）。
- **日志**：使用统一封装的 `logger`，**❌ 禁止 `print()`**。
- **引用库**：优先使用 `pubspec.yaml` 中已有的库，不随意引入新库。

---

## 19. 命名约定

| 对象        | 规范              | 示例                   |
| ----------- | ----------------- | ---------------------- |
| 文件名      | `snake_case`      | `kana_chart_page.dart` |
| 类名        | `PascalCase`      | `KanaChartPage`        |
| 方法/变量   | `camelCase`       | `loadKanaChart()`      |
| 数据库列/表 | `snake_case`      | `kana_learning_state`  |
| 路由名      | `kebab-case`      | `/kana-chart`          |
| Controller  | 后缀 `Controller` | `KanaChartController`  |
| Command     | 后缀 `Command`    | `KanaCommand`          |
| Query       | 后缀 `Query`      | `ActiveUserQuery`      |
| Repository  | 后缀 `Repository` | `KanaRepository`       |
| State       | 后缀 `State`      | `KanaChartState`       |
| Page        | 后缀 `Page`       | `KanaChartPage`        |

---

## 20. 危险操作红线（不可逾越）

| 约束类别      | 规则内容                                                 |
| ------------- | -------------------------------------------------------- |
| 统计数据变更  | 所有 `daily_stats` 写入必须通过 Command，禁止直接操作 DB |
| 跨层访问      | View/Controller 不得直接访问 Repository 或 DB            |
| 路由          | 禁止 `Navigator.push`，必须使用 `context.push/go`        |
| 硬编码文字    | 用户可见字符串必须通过 AppLocalizations                  |
| 日志输出      | 禁止 `print()`，使用 logger                              |
| 统计推导      | 禁止跨模型互推（Word ↔ Kana 统计不互通）                 |
| Feature 结构  | 禁止 Feature 内创建 `domain/` 或 `data/` 子目录          |
| EventBus 事件 | 事件定义只能放在 `lib/core/domain/`                      |

---

## 21. Debug 模块规范

- **仅可调用** Command / Query / Analytics。
- **❌ 禁止** 直连 Repository 或数据库（即便是 Debug 构建也禁止）。

---

## 22. 生成文件与构建命令

| 场景             | 命令                                                       |
| ---------------- | ---------------------------------------------------------- |
| 更新 l10n        | `flutter gen-l10n`                                         |
| 重新生成代码     | `dart run build_runner build --delete-conflicting-outputs` |
| 构建 Android AAB | `flutter build appbundle --release`                        |

- `lib/l10n/app_localizations*.dart` 由 `flutter gen-l10n` 生成，**必须提交到仓库**。
- 修改 `app_zh.arb` 后**必须重新运行** `flutter gen-l10n`。
- 如遇构建错误，优先检查 `*.g.dart`、`*.freezed.dart` 等生成文件。
