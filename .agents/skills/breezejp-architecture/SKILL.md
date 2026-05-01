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
- **时间约定**：所有业务关联时间字段，在 DB 中一律使用 **秒级 Unix 时间戳**。
  - 读取时：`DateTime.fromMillisecondsSinceEpoch(seconds * 1000)`。
  - 写入时：`(DateTime.now().millisecondsSinceEpoch / 1000).round()`。
- **命名区分**：数据库中的表与列定义按 `snake_case`；Dart 中的模型类使用 `PascalCase`，成员变量使用 `camelCase`。
- **取当前用户**：必须由 `ActiveUserQuery` 统一提取（如 `ref.read(activeUserQueryProvider).getActiveUserId()`）。

## 4. 路由系统（Router）执行纪律

- **唯一声明方式**：所有路由均统一在 `lib/router/app_router.dart` 内定义，禁止各级 Feature 各自私下声明路由或注册 Navigator 操作。
- **可用 Api**：必须使用 `context.go()`, `context.replace()`, `context.pop()`。彻底禁用 Flutter 原生的由 Navigator 推导的 API。
- **参数解耦**：导航采用 **路径参数（Path Parameters）**（例如：`/learn/:wordId`），而不应使用 Query 参数来负载核心业务。所有参数兜底以及类型检验必须在 **目标页面（Page Component）内部处理**，不要让 Router 处理业务兜底或决定跳转。

## 5. 统计与学习模型的强制语义约束（最高优先级 ❗）

> **不得混用 Event-based（事件模型）与 State-based（状态模型），不得相互推导。**

### 1️⃣ 词汇（Word）模块

- `study_words`（Status 层）：仅表示“单前的快照状态”（如 `seen`, `learning`, `mastered`, `ignored`）。它不是行为记录，**状态变化不等于发生了学习事件**。
- `study_logs`（Event 层）：用户的离散离轨操作。它的重点是 `firstLearn`：它只产生于**用户第一次点击“加入复习”时**，绝不会因其状态改变成 \`learning\` 而“顺手”生成。每对 (user, word) 有且仅支持最多一笔 `firstLearn` 记录。
- `daily_stats`（Analytics 层）：今日统计事实。`new_learned_count` 完全取决于当日写入 `firstLearn` 的数量。这些写入应直接从由行为触发的 `Command` 中完成（例 `applyLearningDelta`）。严禁去从 log 或者状态拼装推算 “今日复习数及学习数” 供给 UI 侧。

### 2️⃣ 假名（Kana）模块

- **模型设计**：纯 State-based 设计（`kana_learning_state` 表），状态切换于 `learning` <-> `mastered` 间变化。不存在 `firstLearn` 等 `study_logs` 及行为流水录入。
- **产生前置条件**：仅支持在进行**完整的屏幕描红**后被初创记录写入系统。
- **禁止项**：假名的学习/复习进度严禁向 `daily_stats` 的统计字段混入与扩散。

### 3️⃣ 语法（Grammar）模块

- 三层结构组织：`grammars` -> `grammar_meanings`（接续/语意/提示等） -> `grammar_examples`。
- **SRS 控制**：直接通过 `study_grammars` 控制（包含对应复习相关数据）。不需要触发统计结果与 Event 行为日志存储。

### 4️⃣ 学习时长

- 发起源自 `PageDurationTracker`，单通道由 `DailyStatCommand.applyTimeOnlyDelta` 执行存储更新。这个口径独立于由 Session 层提供的常规链路。

## 6. 其他通用红线与工程实践

- **硬编码禁止**：无论是页面占位提示、操作按钮、标题指引，全都由 **`AppLocalizations`** 去提供显示字串，**禁止**直接撰写硬编码对应字符串。
- **Logger 调用**：项目日志由独立的统一 Logger 对象驱动维护。禁止任何直接针对控制台的打印行为（`print()`）。对于异常需按需附加 Error 对象及 StackTrace。
- **保持边界纯粹**：对于功能新增迭代或重构调整：如果存在为了“快速拉取”、“复用省事”而直接在 UI 组件请求 Sqlite 查询、或反过头用 Repository 判断权限/日期的需求，均判定为“架构越界错误代码”。应当优先根据本手册增设对应的 Command / Query，再在 UI 暴露处结合 Controller 去连接使用。
