---
name: breezejp-database
description: BreezeJP 项目的 SQLite 数据库模式、实体关系、表结构详解以及 Repository 实现规范。
---

# BreezeJP 数据库规范与模型

本 Skill 基于 `.kiro/steering/database.md` 以及相关架构文档。当你在进行涉及持久化、数据读取、统计结算或调试功能的排查及编写代码时，**必须严格遵守** 以下规则。

## 1. 核心读写与防越权原则 (SQL / Repository / Controller)

- **绝对隔离**：Controller / View / Debug 层**绝不允许**直接访问数据库，只能调用 Command / Query / Analytics。
- **Repository 纯粹性**：仅包含单表的 CRUD。**绝对禁止**任何含有 join 关联查询、聚合推导、业务条件判定逻辑的 SQL 定义。
- **DB 实例不外露**：在 `xxx_repository.dart` 内部可以调用 `AppDatabase.instance.database`，但是绝不能通过返回值将 Database 对象或者原始结果 (`Map<String, dynamic>`) 泄露出去。只能返回解析好的 Dart Model。
- **Provider 注入**：对于 Query / Analytics 类的只读场景，通过 `databaseProvider` 取 Database 执行。

## 2. 数据库到 Dart 的映射实现规范

- **必须实现序列化模型**：数据库对应的 Dart Model 类必须要实现 `fromMap(Map<String, dynamic>)` 和 `toMap()`。
- **命名转换**：SQLite 的表和字段为 **snake_case**（如 `jlpt_level`, `created_at`）。Dart 实体类名为 **PascalCase**，类变量为 **camelCase**。
- **时间规范 (Unix Timestamp)**：
  - 数据库存的都是 **秒级时间戳 (Seconds)**。
  - Dart 读取时必须：`DateTime.fromMillisecondsSinceEpoch(seconds * 1000)`。
  - Dart 写入时必须转换为秒：`(DateTime.now().millisecondsSinceEpoch / 1000).round()`。
- **全局会话标识**：读取当前使用者应该通过 `ActiveUserQuery`（如 `ref.read(activeUserQueryProvider).getActiveUserId()`），因为它是管理表中 (`app_state.current_user_id`) 映射的单例关系。

## 3. 核心表结构与业务边界

### 【A. 单词与词库模块】(Content Layer)

- **主表**：`words`
- **关联信息 (1:N)**：`word_meanings`、`word_audio`、`example_sentences`、`example_audio`
- **词态扩展**：`word_conjugations` (关联 `conjugation_types`)
- **网状拓展**：`word_relations`（语义关联词），查询结果须使用关联强度 `score` 或特定维度合并（如 DTO）。

### 【B. 单词状态与行为】(State & Event Layer)

- **`study_words`**（状态表）：每个单词随用户的学习进度**时刻状态**。
  - 核心：`user_state` (0=未学, 1=学习中, 2=已掌握, 3=忽略) 和 `next_review_at`。
  - 涵盖基于 SM-2 (interval, ease_factor) 与 FSRS (stability, difficulty) 的调度参数。
  - 此表不可代表行为及任何“新学/复习”语义统计推导。
- **`study_logs`**（行为表）：**不可变的**离散学习行为事实快照！
  - 如 `firstLearn` 是加入复习操作时刻**唯一产生事件**的历史，**不得复写或更新**。不允许用 `study_words` 的新学或跨状态记录反推 `study_logs`。
- **`daily_stats`**（统计表）：记录“确认口径的基础统计”（如 `review_count`, `new_learned_count`, `total_time_ms`，主键包含 `UNIQUE(user_id, date)`）。不能由行为日志表做 Join 实时累加出这批数字！由专属 Command 进行同步写库。

### 【C. 假名学习模块】(Kana Layer)

- **主表**：`kana_letters`，搭配音频 (`kana_audio`)、示例 (`kana_examples`)、SVG 笔画定义 (`kana_stroke_order`)。
- **状态管理表**：`kana_learning_state`。
  - 基于存状态机运转（`learning` <-> `mastered`）。**不允许生成也不应调用** 行为流水表及包含此部分统计在 `daily_stats` 内。

### 【D. 语法学习模块】(Grammar Layer)

- **主表**：`grammars`
- **层级分支**：一条语法产生多种义项 `grammar_meanings`（含中英文释义与接续），独立存储使用场景 `grammar_contexts`，以及挂载在语法下的例句 `grammar_examples`。
- **状态管理表**：`study_grammars`。使用 SRS (FSRS) 原理处理学习进度安排。

## 4. 实体关系

- User 与统计的一对多关系。
- AppState 作为单一对象对 User 表包含一个单向映射。
- 业务表关系，必须通过对应的模型/实体映射明确：对依赖 `1:N` 和 `N:N` 的映射通过独立的 Repository / Query 并装为组合 DTO（不要在基础的 Repository 使用 Group By 或 Left Join）。
