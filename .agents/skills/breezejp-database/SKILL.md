---
name: breezejp-database
description: BreezeJP 项目的 SQLite 数据库模式、实体关系、表结构详解以及 Repository 实现规范。
---

# BreezeJP 数据库规范与模型

本 Skill 基于 BreezeJP 当前仓库里的数据库设计、运行时 schema 与工程规则整理而成，并与 `.github/coding_rules.instructions.md` 及同目录下的专题规约文档共同组成数据库开发基线。当你在进行涉及持久化、数据读取、统计结算或调试功能的排查及编写代码时，**必须严格遵守** 以下规则。

## 1. 核心读写与防越权原则 (SQL / Repository / Controller)

- **绝对隔离**：Controller / View / Debug 层**绝不允许**直接访问数据库，只能调用 Command / Query / Analytics。
- **Repository 纯粹性**：仅包含单表的 CRUD。**绝对禁止**任何含有 join 关联查询、聚合推导、业务条件判定逻辑的 SQL 定义。
- **DB 实例不外露**：在 `xxx_repository.dart` 内部可以调用 `AppDatabase.instance.database`，但是绝不能通过返回值将 Database 对象或者原始结果 (`Map<String, dynamic>`) 泄露出去。只能返回解析好的 Dart Model。
- **Provider 注入**：对于 Query / Analytics 类的只读场景，通过 `databaseProvider` 取 Database 执行。

## 2. 数据库到 Dart 的映射实现规范

- **必须实现序列化模型**：数据库对应的 Dart Model 类必须要实现 `fromMap(Map<String, dynamic>)` 和 `toMap()`。
- **命名转换**：SQLite 的表和字段为 **snake_case**（如 `jlpt_level`, `created_at`）。Dart 实体类名为 **PascalCase**，类变量为 **camelCase**。
- **时间字段规范**：当前仓库的时间字段是**混合制**，禁止做全局秒级假设。
  - 本地 `learning_sessions.created_at` 使用**毫秒整数**。
  - 部分本地用户表仍使用**秒级整数**。
  - seed DB 与远端 `created_at` / `updated_at` 常使用 **ISO/TIMESTAMPTZ**。
  - 读取和写入必须以**具体 schema + Model** 为准，新增字段时要在 DDL 和 Model 注明单位。
- **全局会话标识**：读取当前使用者应该通过 `ActiveUserQuery`（如 `ref.read(activeUserQueryProvider).getActiveUserId()`），因为它是管理表中 (`app_state.current_user_id`) 映射的单例关系。

## 3. 核心表结构与业务边界

### 【A. 运行时本地表】

- 当前运行时会直接使用或保留的本地表：`users`、`app_state`、`sync_metadata`、`learning_sessions`、`kana_letters`、`kana_audio`、`kana_stroke_order`。
- 其中 `learning_sessions` 只保存**活跃会话快照**，用于断点恢复；并不承担长期学习状态权威。
- `users` / `app_state` 来自 seed DB 与运行时组合使用，当前用户必须通过 `ActiveUserQuery` 读取，不能手写 SQL 到处查。

### 【B. 单词与词库模块】(Content + State Layer)

- **远端内容表**：`words`、`word_details`、`word_examples`、`books`、`lessons`、`lesson_word_map`。
- **远端状态表**：`user_word_states`、`user_book_progress`、`user_word_favorites`、`user_word_example_favorites`。
- 当前仓库**不应再引用** `word_meanings`、`word_audio`、`example_sentences`、`example_audio`、`word_conjugations`、`word_relations` 这些旧表名来描述现状。

### 【C. 假名学习模块】(Kana Layer)

- **本地内容表**：`kana_letters`、`kana_audio`、`kana_stroke_order`。
- **远端状态表**：`user_kana_states`。
- 当前运行时说明中不应再把 `kana_examples` 视为现役表。
- 假名复习的会话快照走本地 `learning_sessions`；状态提交走远端 `user_kana_states`。

### 【D. 语法学习模块】(Grammar Layer)

- **远端内容表**：`grammars`、`grammar_meanings`、`grammar_contexts`、`grammar_examples`。
- **远端状态表**：`user_grammar_states`。
- 语法不维护单独的本地状态镜像，不应假定存在可回放的事件表。

### 【E. 问题上报与会话】

- **问题上报**：`issue_reports`，字段使用 `content_type`、`content_id`、`content_snapshot`、`message`、`status`、`admin_note`、`resolved_at`。
- **服务端会话**：`user_learning_sessions`、`user_review_sessions`。
- **本地会话**：`learning_sessions`，通过 `session_type` 区分 `word_learn` / `word_review` / `kana_review`。

## 4. 实体关系

- `app_state.current_user_id -> users.id` 是当前激活用户的唯一入口。
- 单词、语法、文章等内容关系应通过 Query 组装 DTO，不要把 Join / 聚合塞进基础 Repository。
- `learning_sessions` 与远端 `user_learning_sessions` / `user_review_sessions` 是“本地恢复快照 vs 远端权威提交”的关系，不是双向实时同步副本。
