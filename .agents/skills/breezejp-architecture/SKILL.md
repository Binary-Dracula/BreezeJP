---
name: breezejp-architecture
description: BreezeJP 项目的 MVVM 架构规范、数据源流转、路由及统计的工程级限制与规则。
---

# BreezeJP 架构与编码规范

本 Skill 基于当前仓库已经生效的工程规则整理而成，并与 `.github/coding_rules.instructions.md` 一起构成 BreezeJP 的长期开发规则入口。作为 Agent，在 BreezeJP 中进行自动化编码时，**必须严格遵守** 以下强制性规范。

## 1. 核心架构模式

该项目遵循 **MVVM + Command / Query / Analytics / Repository + Session + Riverpod**：

- **目的**：工程解耦与职责隔离，确保写入口集中、读写分离、统计链路可控。
- **状态管理**：`flutter_riverpod`。`NotifierProvider` 用于 Feature Controller，`Provider` 用于 Command / Query / Analytics / Repository。

## 2. 层级划分与严格职责（禁止跨层级调用）

| 层级           | 工程职责                         | 明确禁止项（Hard Limit）                     |
| -------------- | -------------------------------- | -------------------------------------------- |
| **View**       | UI 渲染、用户交互处理            | 访问 Repository/DB、进行统计和业务状态的推导 |
| **Controller** | 编排流程、调度业务、管理 State   | 直接访问 DB 或 Repository                    |
| **Command**    | 唯一写入口、状态变更、触发副作用 | 返回 Map/SQL 原始结果。需实现幂等操作。      |
| **Query**      | 只读查询（List/Join/Detail）     | 任何写操作（禁止触发写状态）                 |
| **Analytics**  | 聚合统计结果查询（只读）         | 任何写操作                                   |
| **Repository** | 单表 CRUD、一致性保证            | Join 查询、聚合统计、承载业务判断逻辑        |
| **Model**      | 数据结构                         | 业务逻辑、行为判断                           |
| **State**      | 不可变状态容器                   | 存在可变字段（Mutable fields）               |
| **External**   | 外部 API/SDK 交互抽象            | 本地持久化、业务裁决                         |
| **Router**     | 声明式页面跳转、参数解析传递     | 拦截检查学习状态、推导/计算统计指标          |

- **依赖流向**：`Feature -> Services -> Data -> Core`。上层可以依赖下层，底层不可反转依赖上层。
- **Debug 模块**：仅可调用 Command/Query/Analytics，禁止直连 Repository 或数据库（即便是 Debug 构建下也禁止）。

## 3. 数据库与数据模型规范

- **存储与注入**：SQLite 数据源位于 `assets/database/breeze_jp.sqlite`。Query 和 Analytics 需要通过 `databaseProvider` 注入 Database 示例进行操作；而 Repository 内部允许调用 `AppDatabase.instance`（但绝不能将其向外暴露给 Controller/UI 层）。
- **对象转换要求**：所有 Model 类必须实现基于 Map 的序列化与反序列化：`fromMap(Map<String, dynamic>)` 和 `toMap()`。
- **时间约定**：当前仓库时间字段并不统一，禁止写“全库秒级时间戳”这类规则。
  - `learning_sessions.created_at` 是毫秒整数。
  - 其他部分本地状态表仍可能是秒级整数。
  - 远端 `created_at` / `updated_at` 多为 ISO/TIMESTAMPTZ。
  - 任何时间比较、序列化和 TTL 逻辑，都必须以具体 Model / schema 为准。
- **命名区分**：数据库中的表与列定义按 `snake_case`；Dart 中的模型类使用 `PascalCase`，成员变量使用 `camelCase`。
- **取当前用户**：必须由 `ActiveUserQuery` 统一提取（如 `ref.read(activeUserQueryProvider).getActiveUserId()`）。

## 4. 路由系统（Router）执行纪律

- **唯一声明方式**：所有路由均统一在 `lib/router/app_router.dart` 内定义，禁止各级 Feature 各自私下声明路由或注册 Navigator 操作。
- **可用 Api**：必须使用 `context.go()`, `context.replace()`, `context.pop()`。彻底禁用 Flutter 原生的由 Navigator 推导的 API。
- **参数解耦**：导航采用 **路径参数（Path Parameters）**（例如：`/learn/:wordId`），而不应使用 Query 参数来负载核心业务。所有参数兜底以及类型检验必须在 **目标页面（Page Component）内部处理**，不要让 Router 处理业务兜底或决定跳转。

## 5. 当前学习模型与状态边界（最高优先级 ❗）

> **不得用历史文档中的事件统计模型覆盖当前已落地的 session + 远端状态模型。**

### 1️⃣ 词汇（Word）模块

- `user_word_states` 是单词学习状态与 SRS 的云端权威。
- `user_book_progress` 是按书聚合的学习进度与 cursor。
- `learning_sessions` 只保存本地活跃会话快照，用于恢复；真正的状态落库发生在 `complete` 时。
- 收藏相关为即时远端写入，不参与旧式 checkpoint 流程。

### 2️⃣ 假名（Kana）模块

- 假名内容来自本地 seed DB：`kana_letters`、`kana_audio`、`kana_stroke_order`。
- 假名状态来自远端 `user_kana_states`。
- `kana_review` 通过 review session 批量提交；单个假名学习通过 `POST /kana/states` 即时写入。
- 禁止把假名进度并入单词的历史统计语义。

### 3️⃣ 语法（Grammar）模块

- 内容结构为 `grammars -> grammar_meanings -> grammar_contexts -> grammar_examples`。
- 状态由 `user_grammar_states` 管理。
- 当前实现没有语法专属本地状态镜像，也不依赖事件表来回放统计。

### 4️⃣ 首页摘要与聚合

- 首页摘要的权威来源是 `/api/v1/me/home-summary`。
- 不允许在 UI / Controller 侧通过本地表或多个状态表手工拼装首页聚合数据。
- 如果未来新增学习时长或其他聚合指标，必须先补 schema / API / 文档，再落代码。

## 6. 其他通用红线与工程实践

- **硬编码禁止**：无论是页面占位提示、操作按钮、标题指引，全都由 **`AppLocalizations`** 去提供显示字串，**禁止**直接撰写硬编码对应字符串。
- **Logger 调用**：项目日志由独立的统一 Logger 对象驱动维护。禁止任何直接针对控制台的打印行为（`print()`）。对于异常需按需附加 Error 对象及 StackTrace。
- **保持边界纯粹**：对于功能新增迭代或重构调整：如果存在为了“快速拉取”、“复用省事”而直接在 UI 组件请求 Sqlite 查询、或反过头用 Repository 判断权限/日期的需求，均判定为“架构越界错误代码”。应当优先根据本手册增设对应的 Command / Query，再在 UI 暴露处结合 Controller 去连接使用。
