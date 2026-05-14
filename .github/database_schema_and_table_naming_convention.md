# BreezeJP 数据库结构与表命名规约

## 1. 本次审计结论

### 1.1 结构结论

当前阶段，本地数据库与云端数据库都**不需要再做新的结构性补表或补字段**，可以作为后续开发基线继续使用。

判断依据如下：

1. 本地 SQLite 的有效 schema 并不只等于 `assets/database/breeze_jp.sqlite`。
   运行时还会由 `lib/data/db/app_database.dart` 执行 `DROP + ensure`：
   - 重建 `learning_sessions` 新 schema（含 `session_type`、`server_session_id`、`data_payload` 等字段）
   - 删除本地旧内容表和旧状态表
   - 保留 `users`、`app_state`、`sync_metadata`
   - 确保 `kana_audio`、`kana_letters`、`kana_stroke_order` 存在并从 assets 回填内容

2. 云端 Supabase 的权威 schema 已统一收口到：
   - `api/supabase/schema.sql`

3. `api/supabase/reset_content_identity_sequences.sql` 属于内容导入后的维护脚本，不再视为独立 schema 来源。

4. 当前学习/复习会话所需的 `user_learning_sessions`、`user_review_sessions` 已纳入主 schema。

5. 本地与云端并不是要求“表集合完全相同”。
   有些表天然是本地专属，有些表天然是云端专属。当前不存在“功能已经上线但缺少承载表”的情况。

6. 云端 schema 当前明确执行：
   - `DROP TABLE IF EXISTS kana_stroke_order`
   - `DROP TABLE IF EXISTS kana_examples`
   - `DROP TABLE IF EXISTS kana_letters`
   - `DROP TABLE IF EXISTS kana_audio`

   这说明假名内容表不是当前正式云端表集合的一部分。

7. `study_logs` / `daily_stats` 目前不是现网代码依赖表。
   代码库中没有真实读写依赖；日志文档里的出现仅是 Logger 示例，不能据此认定现在必须补表。

### 1.2 命名结论

当前 schema 的主要问题**不是结构不完整，而是历史命名风格不统一**。

最明显的不一致来自“同一类用户状态表”：

| 语义         | 本地 SQLite 现名 | 云端 Supabase 现名    | 结论               |
| ------------ | ---------------- | --------------------- | ------------------ |
| 单词学习状态 | （本地已移除）   | `user_word_states`    | 统一以云端命名为准 |
| 语法学习状态 | （本地已移除）   | `user_grammar_states` | 统一以云端命名为准 |
| 假名学习状态 | （本地已移除）   | `user_kana_states`    | 统一以云端命名为准 |
| 书本进度状态 | （本地已移除）   | `user_book_progress`  | 统一以云端命名为准 |

本次结论是：

- **不再新增结构性表改动**。
- **从现在开始冻结统一命名规约**。
- **旧本地状态表名仅作为历史兼容术语保留**，后续文档、接口与新代码统一使用 `user_*` 命名，不再规划本地同语义 rename。

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

- `user_learning_sessions`
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
- 本地学习流程会话：`learning_sessions`

但以后如果再新增本地专属基础设施表，优先使用更明确的命名，不要与云端业务表混淆。

## 3. 当前正式认可的表分类

### 3.1 本地与云端共存的基础元数据表

以下表当前在本地 seed DB 与云端 Supabase schema 中都存在，且保持同名：

- `sync_metadata`

说明：

- 该表属于基础元数据，不属于内容表，也不属于 `user_*` 状态/进度/会话表。
- 当前本地 `AppDatabase._ensureSchema()` 不会删除它，因此它仍是有效本地表的一部分。

### 3.2 当前仍在本地保留的内容表

以下内容表当前仍在本地 SQLite 保留，用于假名图表、音频与笔顺等离线能力：

- `kana_audio`
- `kana_letters`
- `kana_stroke_order`

说明：

- 这三张表当前只保留在本地；远端 `schema.sql` 已显式删除历史 `kana_*` 内容表。

### 3.3 本地专属表

以下表当前定义为本地专属，不要求在云端存在同名表：

- `users`
- `app_state`
- `learning_sessions`

说明：

- `users` 是当前本地账户/会话体系的历史表，不等同于云端 `auth.users`，也不等同于 `user_profiles`。
- `learning_sessions` 是本地学习/复习流程的恢复会话，不等同于云端 `user_learning_sessions` 或 `user_review_sessions`。

### 3.4 云端专属表

以下表当前定义为云端专属，不要求本地存在同名表：

- `articles`
- `article_details`
- `books`
- `grammars`
- `grammar_contexts`
- `grammar_examples`
- `grammar_meanings`
- `issue_reports`
- `lessons`
- `lesson_word_map`
- `user_book_progress`
- `user_devices`
- `user_grammar_states`
- `user_kana_states`
- `user_learning_sessions`
- `user_profiles`
- `user_review_sessions`
- `user_word_example_favorites`
- `user_word_favorites`
- `user_word_states`
- `word_details`
- `word_examples`
- `words`

说明：

- `user_learning_sessions` 与 `user_review_sessions` 是服务端权威会话，不应再回退到本地 SharedPreferences 或本地 SQLite 同名镜像。
- `user_word_favorites` 与 `user_word_example_favorites` 也是当前远端正式表的一部分，不能再按“已删除本地收藏表”误判为全局已下线。
- 当前远端正式表集合不包含 `kana_audio`、`kana_letters`、`kana_stroke_order`、`kana_examples`。

## 4. 已识别的历史命名遗留

以下 4 个本地旧表名已经退出当前 SQLite schema，但仍可能出现在历史文档、旧讨论或日志中：

| 历史本地表            | 当前统一名            | 当前状态 | 说明                                 |
| --------------------- | --------------------- | -------- | ------------------------------------ |
| `study_words`         | `user_word_states`    | 已移除   | 新文档、新接口、新代码统一使用目标名 |
| `study_grammars`      | `user_grammar_states` | 已移除   | 同上                                 |
| `kana_learning_state` | `user_kana_states`    | 已移除   | 同上                                 |
| `book_progress`       | `user_book_progress`  | 已移除   | 同上                                 |

规约要求是：

1. 不再新增任何新的本地或云端表沿用这套旧风格。
2. 历史名只允许出现在迁移说明、兼容说明或故障排查语境中。
3. 在新文档、新设计、新接口命名里，统一使用目标名，而不是继续扩散旧名。

## 5. 对“相同表保持表名一致”的最终解释

这里的“相同表”只指**相同业务语义、相同数据职责**的表，而不是“看起来相似”的表。

因此：

- `sync_metadata` 在本地和云端都存在，且维持同名。
- `study_words` 与 `user_word_states` 代表同一业务语义，但前者已成为历史名。
- `book_progress` 与 `user_book_progress` 代表同一业务语义，但前者已成为历史名。
- `kana_letters` / `kana_audio` / `kana_stroke_order` 当前是本地内容表，不要求云端同名。
- `users` 与 `user_profiles` 不是同一张语义表，不要求同名。
- `learning_sessions` 与 `user_learning_sessions` / `user_review_sessions` 不是同一张语义表，不要求同名。

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

- **结构基线：通过。当前本地有效表集合应理解为 `users`、`app_state`、`sync_metadata`、`learning_sessions`、`kana_audio`、`kana_letters`、`kana_stroke_order`；云端以 `api/supabase/schema.sql` 当前 create/drop 结果为准。**
- **命名基线：统一以当前云端权威表名为准，旧本地状态表名仅作历史兼容术语。**
- **以后所有新增表，必须以本文件作为唯一命名口径。**
