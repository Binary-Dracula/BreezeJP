# 单词增量同步功能档案（已废弃）

## 状态

2026-05 起，旧的 `/api/v1/words/sync` + `WordSyncCommand` 启动增量覆盖方案已经移除，不再作为当前实现的一部分。

## 当前实现

- App 启动阶段只负责确保 active user 与本地数据库可用，不再触发 checkpoint、book sync 或 word sync。
- 词书、单词详情、语法、文章等内容改为页面按需请求远端 API，不再依赖启动期把内容覆盖回本地 SQLite。
- 单词学习、单词复习、假名复习改为 session create/complete；语法状态与收藏等仍保留即时 state upsert；断点恢复只保留在本地 `learning_sessions`。

## 当前权威入口

- 客户端启动：`lib/data/commands/app_bootstrap_command.dart`
- 单词学习会话：`lib/data/queries/vocab_remote_query.dart`
- 复习/状态写入：`lib/data/commands/review_session_remote_command.dart`、`lib/data/commands/word_remote_command.dart`
- Workers 路由：`api/workers/src/routes/vocab.ts`、`api/workers/src/routes/study.ts`

## 保留说明

本文现在只作为旧方案归档提示，避免后续再把 `words/sync` 误认为现役链路。
