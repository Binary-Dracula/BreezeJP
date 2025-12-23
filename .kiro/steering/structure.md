---
inclusion: always
---

# 项目架构与文件组织

## 架构模式：MVVM + Command/Query/Analytics/Repository + Session + Riverpod

**数据流：**

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

**各层职责：**

| Layer               | 职责                                                 | 禁止                                   |
| ------------------- | ---------------------------------------------------- | -------------------------------------- |
| **View**            | UI 渲染、用户交互                                    | 直接访问数据库、业务逻辑、修改 state   |
| **Controller**      | 流程编排、调用 Command / Query / Analytics、状态管理 | 直接 DB 查询、直接调用 Repository      |
| **Command**         | 写行为 / 状态变更 / 副作用入口                       | 返回 Map / SQL 原始结果                |
| **Command/Session** | 会话级流程编排、统计聚合入口                         | 绕过 Session 写 daily_stats/study_logs |
| **Query**           | 只读查询（join / filter / paging / 列表 / 详情）     | 写操作                                 |
| **Analytics**       | 统计聚合 / 报表 / 计数                               | 写操作                                 |
| **Repository**      | Entity CRUD（单表或强一致实体）                      | join / 统计 / 业务语义 / 暴露 Database |
| **External**        | 外部 API Client（HTTP/SDK 适配）                     | 本地持久化或业务语义                   |
| **Model**           | 数据结构，含 `fromMap()`/`toMap()`                   | 业务逻辑                               |
| **State**           | 不可变数据容器                                       | 可变字段、逻辑                         |

**硬性规则：**

- Controller 仅调用 Command / Query / Analytics
- Repository 只返回 Model，不能暴露 Database
- Query / Analytics 只读，使用 `databaseProvider` 注入 Database
- Command 不返回 Map 或 SQL 原始结果
- Session 是统计唯一入口：`SessionStatPolicy → accumulator → flush → DailyStatCommand.applySession`
- External Client 不属于 Repository，独立于 Repository 纯度规则
- Debug 仅通过 Command / Query 访问业务数据，不直连 Repository / DB

## 完整目录结构（与当前代码一致）

```
lib/
├── core/
│   ├── algorithm/
│   ├── constants/
│   ├── network/
│   ├── utils/
│   └── widgets/
├── data/
│   ├── analytics/
│   │   ├── study_log_analytics.dart
│   │   ├── study_word_analytics.dart
│   │   └── word_analytics.dart
│   ├── commands/
│   │   ├── active_user_command.dart
│   │   ├── active_user_command_provider.dart
│   │   ├── app_bootstrap_command.dart
│   │   ├── app_bootstrap_command_provider.dart
│   │   ├── daily_stat_command.dart
│   │   ├── debug/
│   │   │   ├── debug_kana_command.dart
│   │   │   └── debug_kana_command_provider.dart
│   │   ├── kana_command.dart
│   │   ├── kana_command_provider.dart
│   │   ├── study_log_command.dart
│   │   ├── study_session_command.dart
│   │   ├── study_session_command_provider.dart
│   │   ├── study_word_command.dart
│   │   └── session/
│   │       ├── review_result.dart
│   │       ├── session_lifecycle_guard.dart
│   │       ├── session_scope.dart
│   │       ├── session_stat_policy.dart
│   │       ├── study_session_context.dart
│   │       └── study_session_handle.dart
│   ├── db/
│   │   ├── app_database.dart
│   │   └── app_database_provider.dart
│   ├── external/
│   │   ├── example_api_client.dart
│   │   └── example_api_client_provider.dart
│   ├── models/
│   │   ├── read/
│   │   │   ├── daily_stat_stats.dart
│   │   │   ├── example_api_item.dart
│   │   │   ├── jlpt_level_count.dart
│   │   │   ├── kana_accuracy.dart
│   │   │   ├── kana_detail.dart
│   │   │   ├── kana_group_item.dart
│   │   │   ├── kana_learning_stats.dart
│   │   │   ├── kana_log_item.dart
│   │   │   ├── kana_type_item.dart
│   │   │   ├── study_log_item.dart
│   │   │   ├── study_log_stats.dart
│   │   │   ├── user_word_statistics.dart
│   │   │   └── word_list_item.dart
│   │   ├── app_state.dart
│   │   ├── daily_stat.dart
│   │   ├── example_audio.dart
│   │   ├── example_sentence.dart
│   │   ├── kana_audio.dart
│   │   ├── kana_detail.dart
│   │   ├── kana_example.dart
│   │   ├── kana_learning_state.dart
│   │   ├── kana_letter.dart
│   │   ├── kana_log.dart
│   │   ├── kana_stroke_order.dart
│   │   ├── study_log.dart
│   │   ├── study_word.dart
│   │   ├── user.dart
│   │   ├── word.dart
│   │   ├── word_audio.dart
│   │   ├── word_choice.dart
│   │   ├── word_detail.dart
│   │   ├── word_meaning.dart
│   │   └── word_with_relation.dart
│   ├── queries/
│   │   ├── active_user_query.dart
│   │   ├── active_user_query_provider.dart
│   │   ├── daily_stat_query.dart
│   │   ├── kana_query.dart
│   │   ├── kana_query_provider.dart
│   │   ├── study_log_query.dart
│   │   ├── study_word_query.dart
│   │   └── word_read_queries.dart
│   └── repositories/
│       ├── app_state_repository.dart
│       ├── app_state_repository_provider.dart
│       ├── daily_stat_repository.dart
│       ├── daily_stat_repository_provider.dart
│       ├── example_audio_repository.dart
│       ├── example_audio_repository_provider.dart
│       ├── example_repository.dart
│       ├── example_repository_provider.dart
│       ├── kana_repository.dart
│       ├── kana_repository_provider.dart
│       ├── study_log_repository.dart
│       ├── study_log_repository_provider.dart
│       ├── study_word_repository.dart
│       ├── study_word_repository_provider.dart
│       ├── user_repository.dart
│       ├── user_repository_provider.dart
│       ├── word_audio_repository.dart
│       ├── word_audio_repository_provider.dart
│       ├── word_meaning_repository.dart
│       ├── word_meaning_repository_provider.dart
│       ├── word_repository.dart
│       └── word_repository_provider.dart
├── debug/
│   ├── controller/
│   ├── pages/
│   ├── state/
│   ├── tmp/
│   ├── tools/
│   └── widgets/
├── features/
│   ├── home/
│   ├── kana/
│   ├── learn/
│   └── splash/
├── l10n/
├── router/
├── services/
└── main.dart
```

## Data 层规则（当前实现）

- **repositories/**：单表 CRUD，只返回 Model
- **queries/**：只读查询，使用 `databaseProvider` 注入 Database
- **analytics/**：聚合统计，只读
- **commands/**：写行为 / 副作用入口
- **commands/session/**：学习/复习会话编排与统计聚合
- **external/**：外部 API Client（不属于 Repository）
- **db/**：Database 生命周期管理

## Session 架构（学习/复习）

**组件与职责：**

- `StudySessionCommand`：创建 Session
- `StudySessionHandle`：持有会话上下文，提供 `submitFirstLearn` / `submitReview` / `submitKanaReview` / `flush`，并暴露语义化事件方法
- `SessionScope`：`learn` / `wordReview` / `kanaReview`
- `SessionStatPolicy`：事件 → 统计语义映射
- `SessionLifecycleGuard`：flush exactly-once

**硬性规则：**

- Feature 不得直接写 `daily_stats` / `study_logs`
- 统计仅经 Session → `DailyStatCommand.applySession`

## Kana 模块（最终形态）

- `KanaRepository`：`kana_*` 表 CRUD
- `KanaQuery`：kana 只读查询（join/统计/列表）
- `KanaCommand`：kana 学习/复习/日志写入
- 复习统计通过 Session 统一写入

## Debug 层规则

- Debug 仅通过 Command / Query 访问数据
- 禁止 Debug 直连 Repository / DB
- Debug Command 仅用于调试用途，不被 Feature 调用

## 命名与组织规范

**Feature 标准结构：**

```
features/[feature_name]/
├── controller/
├── pages/
├── state/
└── widgets/ (可选)
```

**Repository 配套文件：**

```
repositories/
├── [entity]_repository.dart
└── [entity]_repository_provider.dart
```

## 依赖关系规则

- Features 可以依赖 Data / Services / Core
- Services 可以依赖 Data / Core
- Data 仅依赖 Core
- Debug 仅依赖 Command / Query / Analytics

## Provider 类型使用（当前代码）

| Provider 类型      | 使用场景                   | 示例                                                                       |
| ------------------ | -------------------------- | -------------------------------------------------------------------------- |
| `NotifierProvider` | Feature 状态管理           | `homeControllerProvider`                                                   |
| `Provider`         | Command/Query/Analytics    | `dailyStatQueryProvider`                                                   |
| `Provider`         | Repository / External / DB | `wordRepositoryProvider` / `exampleApiClientProvider` / `databaseProvider` |

## 数据流架构

```
User Interaction → Controller
                      ├─→ Query / Analytics (Read)
                      └─→ Command (Behavior / Write) → Repository → Database
                      ↓
                   State Update → UI Rebuild
```

## 测试目录结构（当前代码）

```
test/
├── features/
└── utils/
```
