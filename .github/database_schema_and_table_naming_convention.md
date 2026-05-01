# BreezeJP 数据库结构与表命名规约

## 1. 本次审计结论

### 1.1 结构结论

当前阶段，本地数据库与云端数据库都**不需要再做新的结构性补表或补字段**，可以作为后续开发基线继续使用。

判断依据如下：

1. 本地 SQLite 的有效 schema 并不只等于 `assets/database/breeze_jp.sqlite`。
   运行时还会由 `lib/data/db/app_database.dart` 自动补齐以下内容：
   - `books.is_available`
   - `learning_sessions.words_payload`
   - `sync_state`
   - `sync_outbox`

2. 云端 Supabase 的权威 schema 已统一收口到：
   - `api/supabase/schema.sql`

3. `api/supabase/reset_content_identity_sequences.sql` 属于内容导入后的维护脚本，不再视为独立 schema 来源。

4. V2 复习续接所需的 `user_review_sessions` 已纳入主 schema，并通过真实线上联调验证。

5. 本地与云端并不是要求“表集合完全相同”。
   有些表天然是本地专属，有些表天然是云端专属。当前不存在“功能已经上线但缺少承载表”的情况。

6. `study_logs` / `daily_stats` 目前不是现网代码依赖表。
   代码库中没有真实读写依赖；日志文档里的出现仅是 Logger 示例，不能据此认定现在必须补表。

### 1.2 命名结论

当前 schema 的主要问题**不是结构不完整，而是历史命名风格不统一**。

最明显的不一致来自“同一类用户状态表”：

| 语义         | 本地 SQLite 现名      | 云端 Supabase 现名    | 结论             |
| ------------ | --------------------- | --------------------- | ---------------- |
| 单词学习状态 | `study_words`         | `user_word_states`    | 需要统一命名口径 |
| 语法学习状态 | `study_grammars`      | `user_grammar_states` | 需要统一命名口径 |
| 假名学习状态 | `kana_learning_state` | `user_kana_states`    | 需要统一命名口径 |
| 书本进度状态 | `book_progress`       | `user_book_progress`  | 需要统一命名口径 |

本次结论是：

- **不再新增结构性表改动**。
- **从现在开始冻结统一命名规约**。
- **历史遗留表暂不在本轮直接 rename**，因为 rename 本身会构成一次新的破坏性 schema 变更；但以后若进入专门的本地/云端破坏性迁移窗口，上面 4 组表应优先统一。

## 2. 统一命名原则

以后新增表，必须遵守以下规则。

### 2.1 内容表

内容表使用**无用户前缀的复数名词**，代表全局共享内容。

示例：

- `words`
- `word_details`
- `word_examples`
- `books`
- `lessons`
- `lesson_word_map`
- `grammars`
- `grammar_meanings`
- `grammar_contexts`
- `grammar_examples`
- `kana_letters`
- `kana_audio`
- `kana_examples`
- `kana_stroke_order`
- `articles`
- `article_details`

### 2.2 用户状态表

凡是“每个用户对某个对象的当前状态快照”，统一命名为：

`user_<domain>_states`

示例：

- `user_word_states`
- `user_grammar_states`
- `user_kana_states`

禁止再新增以下风格：

- `study_words`
- `study_grammars`
- `xxx_learning_state`
- 单数 `*_state` 用于多行状态表

### 2.3 用户进度表

凡是“每个用户对某个聚合对象的累计进度”，统一命名为：

`user_<domain>_progress`

示例：

- `user_book_progress`

### 2.4 用户会话表

凡是“用户在某种流程中的可恢复会话快照”，统一命名为：

`user_<domain>_sessions`

示例：

- `user_review_sessions`

### 2.5 用户账户与档案表

用户主身份与用户资料必须分开看待：

- `auth.users`：认证主表，由 Supabase 托管
- `user_profiles`：业务资料表

不要把本地离线账户缓存、当前用户指针、云端 profile 这三种语义混成同一个名字。

### 2.6 本地客户端专属表

本地专属、不会直接与云端同名镜像的表，可以继续保留明确的客户端语义命名。

允许的语义类型：

- App 单例状态：`app_state`
- 同步游标状态：`sync_state`
- 同步待推送队列：`sync_outbox`
- 本地学习流程会话：`learning_sessions`

但以后如果再新增本地专属基础设施表，优先使用更明确的命名，不要与云端业务表混淆。

## 3. 当前正式认可的表分类

### 3.1 本地与云端共用命名的内容表

以下表名在本地和云端已经一致，后续保持不变：

- `articles`
- `article_details`
- `sync_metadata`
- `words`
- `word_details`
- `word_examples`
- `books`
- `lessons`
- `lesson_word_map`
- `grammars`
- `grammar_meanings`
- `grammar_contexts`
- `grammar_examples`
- `kana_audio`
- `kana_letters`
- `kana_examples`
- `kana_stroke_order`

### 3.2 本地专属表

以下表当前定义为本地专属，不要求在云端存在同名表：

- `users`
- `app_state`
- `learning_sessions`
- `sync_state`
- `sync_outbox`

说明：

- `users` 是当前本地账户/会话体系的历史表，不等同于云端 `auth.users`，也不等同于 `user_profiles`。
- `learning_sessions` 是本地学习流程会话，不等同于云端 `user_review_sessions`。
- `sync_state` / `sync_outbox` 属于客户端同步基础设施，不是云端业务事实表。

### 3.3 云端专属表

以下表当前定义为云端专属，不要求本地存在同名表：

- `issue_reports`
- `user_profiles`
- `user_devices`
- `sync_mutation_receipts`
- `user_sync_events`
- `user_review_sessions`

说明：

- `user_review_sessions` 是服务端权威复习会话，不应再回退到本地 SharedPreferences 或本地 SQLite 同名镜像。

## 4. 已识别的历史命名遗留

以下 4 组表名，语义上建议统一到云端命名口径：

| 当前本地表            | 建议统一名            | 是否本轮执行 rename | 原因                                                                    |
| --------------------- | --------------------- | ------------------- | ----------------------------------------------------------------------- |
| `study_words`         | `user_word_states`    | 否                  | 当前线上功能已稳定，rename 会引入本地迁移、仓库改名、同步映射和测试重写 |
| `study_grammars`      | `user_grammar_states` | 否                  | 同上                                                                    |
| `kana_learning_state` | `user_kana_states`    | 否                  | 同上                                                                    |
| `book_progress`       | `user_book_progress`  | 否                  | 同上                                                                    |

这 4 个名字从今天起视为**历史遗留名**。

规约要求是：

1. 不再新增任何新的本地或云端表沿用这套旧风格。
2. 以后如果进入专门的破坏性数据库迁移窗口，优先统一这 4 组名字。
3. 在新文档、新设计、新接口命名里，统一使用目标名，而不是继续扩散旧名。

## 5. 对“相同表保持表名一致”的最终解释

这里的“相同表”只指**相同业务语义、相同数据职责**的表，而不是“看起来相似”的表。

因此：

- `study_words` 和 `user_word_states` 是同一业务语义，应统一命名。
- `book_progress` 和 `user_book_progress` 是同一业务语义，应统一命名。
- `users` 与 `user_profiles` 不是同一张语义表，不要求同名。
- `learning_sessions` 与 `user_review_sessions` 不是同一张语义表，不要求同名。
- `sync_outbox` 与 `user_sync_events` / `sync_mutation_receipts` 不是同一层职责，不要求同名。

## 6. 后续开发强制规约

从本文件生效后，后续开发必须遵守：

1. 新增共享内容表时，使用无前缀复数名词。
2. 新增用户状态表时，统一使用 `user_<domain>_states`。
3. 新增用户进度表时，统一使用 `user_<domain>_progress`。
4. 新增用户会话表时，统一使用 `user_<domain>_sessions`。
5. 不再新增 `study_*`、`*_learning_state`、单数 `*_state` 这类旧风格名字。
6. 本地与云端如果承载同一业务事实，必须从建表当天开始使用同一个表名。
7. 本地专属表、云端专属表必须在设计文档里显式标记 `local-only` 或 `remote-only`。
8. 若未来要执行本地/云端表 rename，必须单独立项，不能在业务开发中顺手夹带。

## 7. 当前基线结论

截至本次审计，BreezeJP 的数据库基线结论如下：

- **结构基线：通过，不需要继续补结构。**
- **命名基线：已有统一规约，但存在 4 组本地历史遗留表名待未来专门迁移窗口统一。**
- **以后所有新增表，必须以本文件作为唯一命名口径。**