# Breeze JP API & 数据同步策略重构

> 状态（2026-05-13）：本文对应的重构已经落地完成。文中出现的“删除”“废弃”“迁移”均视为已完成事项；当前权威实现以实际代码、workers 路由和 `api/supabase/schema.sql` 为准。本文保留为历史设计记录。
>
> 说明：本文中的历史背景和“删除列表”会保留旧表名；凡描述**当前落地状态、当前本地表结构、当前云端表结构**的段落，已按现状校正。

## 背景与问题

原有同步机制存在以下问题：

1. **API 调用过于频繁**：90 秒定时器持续轮询，App 从后台恢复时触发（距上次超过 30 秒），每次业务操作（学单词、收藏、标记掌握等）后 5 秒防抖触发 sync/checkpoint
2. **全量快照同步**：每次 checkpoint 将全部本地用户状态序列化上传（`user_word_states` + `user_kana_states` + `user_grammar_states` + favorites + `user_book_progress`），服务端也返回全量数据覆盖本地。只改一条数据却要传输所有数据
3. **学习过程中持续同步**：每翻一张单词卡片就触发 `markAsLearned` → `scheduleCheckpoint`，20 个单词的学习可能触发多次全量同步
4. **两份数据源**：用户状态在本地 SQLite 和云端各存一份，需要持续保持同步，容易不一致
5. **内容表冗余**：单词、语法、书籍、文章等数据在本地 SQLite 和 Supabase 各存一份，需要增量同步（books/sync、words/sync）

## 核心设计目标

1. **会话批次同步**：单词学习取一批到本地，学完一次性提交，中途退出从本地恢复，未完成不提交。复习同理
2. **用户状态完全云端化**：所有学习进度、SRS 参数、收藏数据只存云端。本地 SQLite 仅保留当前活跃会话（断点恢复用）和假名内容（seed DB）
3. **内容数据 API 即时获取**：词书列表、单词详情、语法、文章等从 API 即时获取，不在本地 SQLite 缓存
4. **取消所有定时/轮询/事件同步**：不主动同步。只在用户行为边界触发网络请求：完成学习、完成复习、切换收藏、登录后加载首页
5. **会话串行化**：word_learn 每本书一个活跃学习会话（可同时学多本书）；word_review / kana_review 每种类型同时只有一个活跃会话。均由服务端唯一索引保证，完成时用 `UPDATE WHERE status='active' RETURNING id` 原子检查，先到先得
6. **假名数据分层**：假名内容（字母表、音频、笔画）本地 seed DB；假名学习状态云端（`/me/kana-states` 获取，`/kana/states` 即时写入）

## 三种 Session 统一模型

| Session 类型             | 创建 API                            | 数据来源                          | 完成时写入                            |
| ------------------------ | ----------------------------------- | --------------------------------- | ------------------------------------- |
| 单词学习 (`word_learn`)  | POST /learn/sessions                | 书 + 单词表（按 cursor 取下一批） | user_word_states + user_book_progress |
| 单词复习 (`word_review`) | POST /review/sessions {kind:"word"} | user_word_states（到期 + 学习中） | user_word_states（SRS 更新）          |
| 假名复习 (`kana_review`) | POST /review/sessions {kind:"kana"} | user_kana_states（到期 + 学习中） | user_kana_states（SRS 更新）          |

三种 session 共用同一套逻辑：创建 → 本地存储 → 学习/复习 → 完成时原子提交 → 冲突返回 409 STALE_SESSION → 删除本地 session。本地 `learning_sessions` 表通过 `session_type` 字段区分。**唯一索引规则**：word_learn 按 `(user_id, book_id)` 唯一（可同时学多本书）；word_review / kana_review 按 `(user_id, session_type)` 唯一。

## 完整数据流

### 正常单词学习

```
① 用户进入学习页 → POST /learn/sessions {book_id}
  服务端：读取 user_book_progress.current_sort_cursor → 查询下一批单词 → 创建 user_learning_sessions → 返回 {session_id, words}
② 客户端：写入本地 learning_sessions（含 data_payload 完整数据）
③ 逐张学习：翻到卡片 → 更新本地 current_index。无网络请求
④ 全部学完 → POST /learn/sessions/:id/complete
  服务端：UPDATE WHERE id=X AND status='active' RETURNING id（原子检查）
  成功 → 批量 UPSERT user_word_states + 重新计算 user_book_progress
  失败 → 返回 409 STALE_SESSION
⑤ 客户端：成功 → 删除本地 session；网络失败 → 保留本地 session（不删除），下次进入学习页检测到 current_index == words.length 时自动重试；409 STALE_SESSION → 删除本地 session → 自动 POST /learn/sessions {book_id} 进入下一批，无需提示用户
```

### 中途退出恢复

```
用户学了 8/20 → 退出 → 再次打开学习页
① 查询本地 learning_sessions WHERE status='active'
② 找到 → 从 data_payload 恢复单词 + 从 current_index 恢复进度
③ 无网络请求，直接继续学习
```

### 设备切换

```
Device A 有活跃 session S1（学了 8/20）
→ 用户打开 Device B → POST /learn/sessions {book_id}
→ 服务端检测到已有 active session S1 → 返回已有会话（含 words_payload）
→ Device B 写入本地 → 从 current_index=0 开始（服务端不知道 A 的进度）
→ Device B 学完 → POST /learn/sessions/S1/complete → 成功
→ Device A 再打开 → POST complete → WHERE status='active' → 0 rows → 409 → 删除本地 session → 自动 POST /learn/sessions {book_id} 获取 B 完成后的新一批词，直接进入下一批，无需提示用户
```

### 单词复习

```
① POST /review/sessions {kind:"word", limit:20}
  服务端：若已有 active session → 直接返回已有 session（含 items）
         若无 → 查询到期单词 → 生成题目 → 创建 user_review_sessions（存 items）→ 返回 {session_id, items}
② 客户端：写入本地 learning_sessions（session_type=word_review，
          data_payload = { initial_items, dynamic_queue: [...items], answered_results: [], current_index: 0 }）
③ 逐题复习：
   - 答对/答错 → 追加 {word_id, rating} 到 answered_results，错题追加到 dynamic_queue 末尾
   - 每题答完 → 更新本地 data_payload 快照（本地 SQLite write，无网络请求）
④ 全部完成 → POST /review/sessions/:id/complete {results: answered_results}
  原子检查 + 批量 UPSERT user_word_states（SRS 更新）
```

**中途退出恢复**：进入复习页时：

1. 先检查本地 active session 的 `created_at`——若超过 7 天，视为过期：删除本地 session，改走 `POST /review/sessions {kind}` 创建新会话（服务端同步将旧 active session 标为 `abandoned`）。
2. 未过期 → 从 `data_payload.dynamic_queue` 恢复题目队列，从 `data_payload.current_index` 恢复进度，从 `data_payload.answered_results` 恢复已答结果。

### 单词复习设备切换

```
Device A 复习进行中（本地 current_index=10/20）
→ 用户打开 Device B → POST /review/sessions {kind:"word"}
→ 服务端检测到已有 active session → 返回已有 session（含 items）
→ Device B 写入本地 → 从 current_index=0 开始（服务端不存中间进度）
→ Device B 全部完成 → POST complete → 成功
→ Device A 再 complete → 409 → 删除本地 session → 自动创建新复习会话
```

### 假名复习

```
① POST /review/sessions {kind:"kana", limit:20}
  服务端：若已有 active session → 直接返回已有 session（含 items）
         若无 → 查询 user_kana_states（到期 + 学习中）→ 生成 kana review 题目 payload（含选项、题型）
         → 创建 user_review_sessions（存 items）→ 返回 {session_id, items}
② 客户端：写入本地 learning_sessions（session_type=kana_review，
          data_payload = { initial_items, dynamic_queue: [...items], answered_results: [], current_index: 0 }）
③ 逐题复习：
   - 答对/答错 → 追加 {kana_id, rating} 到 answered_results，错题追加到 dynamic_queue 末尾
   - 每题答完 → 更新本地 data_payload 快照（本地 SQLite write，无网络请求）
④ 全部完成 → POST /review/sessions/:id/complete {results: answered_results}
  原子检查 + 批量 UPSERT user_kana_states（SRS 更新）
```

**中途退出恢复**：同单词复习，从本地 data_payload 快照恢复队列、进度和已答结果。

### 假名学习（非复习场景）

```
① 用户学习单个假名 → POST /kana/states 即时写入云端
② 进入假名列表页 → GET /me/kana-states 获取全部状态
③ 客户端合并 kana_letters（本地 seed DB）+ user_kana_states（云端）
```

### 收藏

```
POST /favorites/words/toggle {word_id}
服务端：已存在则 DELETE，不存在则 INSERT → 返回 {favorited: true/false}
即时同步，不参与 session

POST /favorites/examples/toggle {example_id, word_id}
同上
```

> **`book_id` 从收藏接口移除**：旧契约要求客户端传 `book_id`，由 `resolveBookIdForWord()` 从本地 `lesson_word_map`/`study_words` 推导。这两张表在本次一次性切换中会被删除，该推导路径随之断裂。新契约去掉 `book_id` 参数，服务端通过 `word_id` 自行关联 `user_word_states` 或 books 表解析所属书（收藏本身不依赖 book 归属做业务逻辑，存 book_id 是历史冗余）。

### 语法状态

```
POST /grammar/states {states: [{grammar_id, learning_status, ...}]}
即时同步，每次状态变更触发
```

### 设备切换后的假名同步

```
Device A 学了一些假名 → Device B 打开假名页
→ GET /me/kana-states → 服务端返回全部状态
→ Device B 直接使用服务端返回的状态（无本地缓存）
→ 展示最新进度
```

## API 端点清单

### 新增（9 个）

| 端点                                   | 方法 | 用途                                                                                                                                                                                                                                                                                                    |
| -------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/api/v1/learn/sessions`               | POST | 创建单词学习会话                                                                                                                                                                                                                                                                                        |
| `/api/v1/learn/sessions/:id/complete`  | POST | 完成学习（批量写 `user_word_states` + `user_book_progress`）                                                                                                                                                                                                                                            |
| `/api/v1/review/sessions`              | POST | 创建复习会话 `{kind:"word"\|"kana"}`                                                                                                                                                                                                                                                                    |
| `/api/v1/review/sessions/:id/complete` | POST | 完成复习（批量写 SRS 更新）                                                                                                                                                                                                                                                                             |
| `/api/v1/review/sessions/:id/abandon`  | POST | 显式丢弃复习会话（标为 abandoned）                                                                                                                                                                                                                                                                      |
| `/api/v1/grammar/states`               | POST | 语法状态即时同步                                                                                                                                                                                                                                                                                        |
| `/api/v1/kana/states`                  | POST | 假名状态即时同步                                                                                                                                                                                                                                                                                        |
| `/api/v1/grammars`                     | GET  | 语法列表（有序，含学习状态），支持 `?jlpt_level=N` 过滤；同时替代 `GET /grammar-learning/queue`：支持 `?exclude_ids=id1,id2&unlearned_only=true&limit=N`，返回下一批未学习语法及完整 detail bundle（grammar + meanings + contexts + examples + learning_status），供 `GrammarLearningPage` 连续翻卡使用 |
| `/api/v1/me/kana-states`               | GET  | 获取用户全部假名学习状态                                                                                                                                                                                                                                                                                |

### 保留不变（7 个）

| 端点                                | 方法 | 说明                                                                                                                                                                                                                                                         |
| ----------------------------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/api/v1/books`                     | GET  | 书单（可选认证，已登录附带用户 `user_book_progress`）                                                                                                                                                                                                        |
| `/api/v1/grammars/:id`              | GET  | 语法详情                                                                                                                                                                                                                                                     |
| `/api/v1/articles`                  | GET  | 文章列表                                                                                                                                                                                                                                                     |
| `/api/v1/articles/:id`              | GET  | 文章详情                                                                                                                                                                                                                                                     |
| `/api/v1/favorites/examples/toggle` | POST | 例句收藏切换                                                                                                                                                                                                                                                 |
| `/api/v1/me/word-book`              | GET  | 单词本（分页，请求参数：`?status=learning/mastered/ignored/favorite`、`?search=keyword`、`?limit=20`、`?offset=0`；响应 `meta` 包含 `total_count`、`has_more`、`server_time`；`status=favorite` 服务"单词本-收藏"页签，替代原本地 `user_word_favorites` 表） |
| `/api/v1/me/grammar-book`           | GET  | 语法本（分页，请求参数：`?status=learning/mastered`、`?search=keyword`、`?limit=20`、`?offset=0`；响应 `meta` 包含 `total_count`、`has_more`、`server_time`）                                                                                                |

### 保留路径但修改契约（4 个）

| 端点                             | 方法 | 变更说明                                                                                                                                                                                                                                                                                                                                                               |
| -------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/api/v1/me/home-summary`        | GET  | 新增 `kana_mastered_count` 字段；`mastered_word_count` 语义收窄为仅统计单词 mastered（不含 kana）；客户端改为每次进入首页直接 GET，不再读本地投影。**客户端 `isNewUser` 判断**：改为 `mastered_word_count == 0`（保持原逻辑，即"尚未 mastered 任何单词"）——kana 和单词是独立学习路径，首页单词学习引导只看单词掌握数                                                   |
| `/api/v1/favorites/words/toggle` | POST | **移除 `book_id` 参数**，改为仅传 `{word_id}`；服务端通过 `word_id` 自行解析（`book_id` 是历史冗余，旧客户端依赖已删表 `lesson_word_map` 推导，新契约不再需要）                                                                                                                                                                                                        |
| `/api/v1/words/:id`              | GET  | **新增 `is_favorited` 和每条 example 的 `is_favorited` 字段**（需认证，未登录时均返回 `false`）；替代原本地 `user_word_favorites`/`user_word_example_favorites` 表作为收藏状态读取源，供详情页、学习页、复习页的收藏按钮初始状态渲染使用                                                                                                                               |
| `/api/v1/me/example-favorites`   | GET  | 例句收藏列表（分页，请求参数：`?search=keyword`、`?limit=20`、`?offset=0`；响应 `meta` 包含 `total_count`、`has_more`、`server_time`）。**客户端契约变更**：列表中每条记录按定义均为已收藏，`WordExampleFavoriteButton` 不再走 `wordExampleFavoriteStateProvider` 查状态，直接以 `is_favorited = true` 初始化；用户点击取消收藏后从列表本地移除该项，无需回查 provider |

### 废弃（10 个端点 + 客户端组件）

| 端点                                 | 原因                      |
| ------------------------------------ | ------------------------- |
| `POST /api/v1/sync/checkpoint`       | 全量快照 → 各业务端点替代 |
| `GET /api/v1/books/sync`             | 内容不再本地缓存          |
| `GET /api/v1/words/sync`             | 内容不再本地缓存          |
| `GET /api/v1/learn/books/:id/next`   | 学习会话替代              |
| `GET /api/v1/review/words/session`   | 复习会话替代              |
| `POST /api/v1/review/words/session`  | 复习会话替代              |
| `GET /api/v1/grammar-learning/queue` | GET /grammars 替代        |
| `SyncSchedulerCommand`（客户端）     | 取消 90s 定时器           |
| `scheduleCheckpoint()` 所有调用点    | 取消事件触发同步          |
| `syncDisplacedProvider`              | 取消设备接管/被踢机制     |

## 数据库变更

### 服务端新增

```sql
CREATE TABLE user_learning_sessions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         UUID NOT NULL,
    book_id           UUID NOT NULL,
    status            TEXT DEFAULT 'active' CHECK (status IN ('active','completed','abandoned')),
    word_ids          UUID[] NOT NULL,
    words_payload     JSONB,         -- 单词完整数据（设备切换恢复用）
    batch_start_sort  INTEGER NOT NULL,
    batch_end_sort    INTEGER NOT NULL,
    completed_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

-- 每用户每书同时只有一个活跃学习会话（word_learn）
CREATE UNIQUE INDEX idx_learning_sessions_active_book
    ON user_learning_sessions(user_id, book_id) WHERE status = 'active';

-- 每用户每复习类型同时只有一个活跃复习会话（word_review / kana_review）
CREATE UNIQUE INDEX idx_review_sessions_active_kind
    ON user_review_sessions(user_id, session_kind) WHERE status = 'active';
```

### 服务端修改

- `user_review_sessions`：扩展 CHECK `session_kind IN ('word', 'kana')`；保留 `current_index` 作为 session envelope 字段；`current_phase`、`has_mistake_on_current` 已从 schema 删除；现有 `items JSONB` 字段即为创建时的题目 payload，**不新增** `words_payload` 字段
- 当前云端正式 schema 不再把 `kana_letters` 作为一张需要对外维护的正式内容表写入本文表结构说明
- 删除 `sync_checkpoint()` RPC 函数
- 删除 `user_profiles.active_device_id` 列
- 删除 `sync_mutation_receipts`、`user_sync_events` 表（如存在）

### 客户端本地 SQLite

保留 / 运行时直接使用（7 张表）：

- `users` — 本地用户标识
- `app_state` — 当前激活用户与本地运行时状态
- `sync_metadata` — seed DB / 内容元信息
- `learning_sessions` — 活跃会话（新增 session_type、data_payload、server_session_id 字段；原 `words_payload` 重命名为 `data_payload`；**移除** `current_phase` 列（复习进度状态统一存 data_payload，不单独列）；`book_id` 改为可空，word_review/kana_review 填 NULL；唯一索引拆为两条：word_learn 用 `(user_id, book_id) WHERE session_type='word_learn' AND status='active'`，复习类型用 `(user_id, session_type) WHERE session_type!='word_learn' AND status='active'`）
- `kana_letters`、`kana_audio`、`kana_stroke_order` — 假名内容（seed DB，用于图表展示/笔顺/音频）

删除：

- 内容表：words、word_details、word_examples、grammars、grammar_meanings、grammar_contexts、grammar_examples、books、lessons、lesson_word_map、articles、article_details
- 用户状态表：study_words、book_progress、study_grammars，以及旧本地镜像版 `user_word_favorites`、`user_word_example_favorites`
- 废弃表：sync_outbox、sync_state、kana_examples、kana_learning_state

> `sync_state` 和 `sync_outbox` 随 sync/checkpoint 机制一并废弃。
> **设备 ID 不再需要 SQLite 存储**：新系统中 device_id 仅用于会话记录的附属字段（不参与业务逻辑），改为在 SharedPreferences 中存一个安装时生成的 UUID，随 session 创建请求一起发送即可。
> **SQLite 版本升级策略（开发阶段）**：当前项目处于开发阶段，尚无存量用户数据，升级时直接 `DATABASE_VERSION++`，`onUpgrade` 中 DROP + 重建所有表。进入公测前需补充逐字段迁移 DDL：列重命名（`words_payload` → `data_payload`、`current_phase` 列删除）、旧 unique index 替换、`session_type` 补填、旧 completed session 清除。

## 会话冲突处理

所有 complete 接口使用 `UPDATE WHERE status='active' RETURNING id`：

- 有结果 → 原子成功，先到先得
- 无结果 → 已被处理 → 返回 409 STALE_SESSION
- 网络错误（complete 请求失败）→ 保留本地 session，下次进入时自动重试
- 收到 409 STALE_SESSION → 删除本地 session → 自动创建新会话，无提示

### 复习 Session 过期与丢弃规则

`user_review_sessions` 的 `active` 状态若长期不完成，会永久阻塞新复习队列。为此定义两套退出机制：

**TTL 自动过期**：服务端处理 `POST /review/sessions {kind}` 时，若已有 active session 且 `created_at` 超过 7 天，先将其标为 `abandoned`，再创建新 session 返回给客户端。客户端无需感知。

**显式丢弃**：`POST /review/sessions/:id/abandon` — 客户端主动放弃当前 session（如：检测到拿到的是旧队列，UI 提示用户"是否重新取最新到期题目"）。服务端将状态改为 `abandoned`，客户端删除本地 session，再调 `POST /review/sessions {kind}` 获取新队列。

| 退出方式       | 触发条件                         | 处理方                                             |
| -------------- | -------------------------------- | -------------------------------------------------- |
| TTL 自动过期   | `created_at` > 7 天              | 服务端（POST /review/sessions 时检查）             |
| **客户端 TTL** | 本地 session `created_at` > 7 天 | 客户端恢复入口：删除本地 session → POST 创建新会话 |
| 显式 abandon   | 客户端主动                       | `POST /review/sessions/:id/abandon`                |

## 同步触发点总结

| 场景                | 同步动作                       | 数据量                            |
| ------------------- | ------------------------------ | --------------------------------- |
| 登录/注册后         | loadHomeData（预加载首页摘要） | 一次 GET                          |
| 进入首页            | loadHomeData                   | 一次 GET                          |
| 学习会话完成        | learn/complete                 | 批量推送 20 条 `user_word_states` |
| 复习会话完成        | review/complete                | 批量推送 20 条 SRS 更新           |
| 收藏切换            | favorites/toggle               | 单条 upsert/delete                |
| 语法状态变更        | grammar/states                 | 即时推送                          |
| 假名状态变更        | kana/states                    | 即时推送                          |
| 下拉刷新            | re-loadHomeData                | 一次 GET                          |
| ~~90s 定时器~~      | ~~已移除~~                     |                                   |
| ~~App 恢复~~        | ~~已移除~~                     |                                   |
| ~~每次单词操作~~    | ~~已移除~~                     |                                   |
| ~~sync_checkpoint~~ | ~~已移除~~                     |                                   |

## 同步量对比

| 场景           | 旧方案                                       | 新方案                         |
| -------------- | -------------------------------------------- | ------------------------------ |
| App 启动       | 1 次 checkpoint（push+pull 全量 ~200-500KB） | 无（或 1 次 GET ~1KB）         |
| 学习 20 个单词 | 1-3 次 checkpoint（每次全量）                | 1 次 complete（仅 20 条 ~2KB） |
| 复习 20 个单词 | 1-3 次 checkpoint                            | 1 次 complete（仅 20 条 ~2KB） |
| 收藏 1 个单词  | 1 次 checkpoint（全量）                      | 1 次 toggle（单行）            |
| 1 小时内定时器 | 40 次 checkpoint                             | 0                              |
| App 切换 10 次 | 10 次 checkpoint                             | 0                              |

## 关于 learning_sessions 的 book_id 与唯一索引

`kana_review` 类型的 session 没有对应的 book_id，`word_review` 也不按书区分，因此本地唯一索引拆成两条：

- `book_id` 列改为可空（`TEXT` → `TEXT NULL`），word_learn 填充具体 book_id，word_review / kana_review 填 NULL
- **word_learn**：唯一索引 `(user_id, book_id) WHERE session_type='word_learn' AND status='active'`，每本书一个活跃学习会话，可同时学多本书
- **word_review / kana_review**：唯一索引 `(user_id, session_type) WHERE session_type!='word_learn' AND status='active'`，每种复习类型同时最多一个活跃会话
- 查询活跃会话：word_learn 用 `WHERE user_id + book_id + session_type='word_learn' + status='active'`；复习类型用 `WHERE user_id + session_type + status='active'`

## 关于 user_book_progress 与 user_learning_sessions 的关系

两张表各有用途，不是两套游标：

- **`user_book_progress.current_sort_cursor`**：持久状态，代表用户已学到哪个位置。只在一个地方更新——学习会话完成时
- **`user_learning_sessions.batch_start_sort / batch_end_sort`**：临时标记，当前批次的单词排序范围。创建时从 `user_book_progress.current_sort_cursor` 读取 cursor 确定起始位置，完成时把 end 写回 `user_book_progress`

创建会话：读 cursor → 查 sort_order > cursor 的下一批 → 记录 batch_start/end
学习过程：两边都不动
完成会话：`UPDATE user_book_progress SET current_sort_cursor = MAX(current_sort_cursor, session.batch_end_sort)` + 重新 COUNT 各状态数量

`user_book_progress` 表本身保留不变，只是更新时机从"每次翻卡"改为"会话完成时一次性更新"。中途退出不更新 cursor，下次会拿到同一批单词。

**本地 `learning_sessions` 目标列清单：**

| 列名                | 类型          | 说明                                                 |
| ------------------- | ------------- | ---------------------------------------------------- |
| `id`                | TEXT PK       | 本地生成的 UUID                                      |
| `user_id`           | TEXT NOT NULL | 用户 ID                                              |
| `session_type`      | TEXT NOT NULL | `word_learn` / `word_review` / `kana_review`         |
| `server_session_id` | TEXT          | 服务端返回的 session ID                              |
| `book_id`           | TEXT NULL     | word_learn 填写，复习类型填 NULL（唯一索引依赖此列） |
| `status`            | TEXT NOT NULL | `active` / `completed`                               |
| `data_payload`      | TEXT NOT NULL | JSON，三种类型内容见下表                             |
| `created_at`        | INTEGER       | 创建时间戳（毫秒，用于客户端 TTL 检查）              |

`current_index`、`batch_start_sort`、`batch_end_sort` **不保留为独立列**，均存入 `data_payload`（见下表）。`current_phase` 列已移除。

**三种 session 的 data_payload 内容（本地快照，每题答完更新）：**

| session_type  | data_payload 内容                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `word_learn`  | 单词列表（每词含 `is_favorited`）+ `batch_start_sort` + `batch_end_sort` + `current_index`                                      |
| `word_review` | `initial_items`（初始题目）+ `dynamic_queue`（含追加错题的当前队列）+ `answered_results: [{word_id, rating}]` + `current_index` |
| `kana_review` | `initial_items`（初始题目）+ `dynamic_queue`（含追加错题的当前队列）+ `answered_results: [{kana_id, rating}]` + `current_index` |

**复习 session 恢复语义**：`data_payload.current_index` 是进度的唯一可信源，等于已完成答题数（即 `answered_results.length`）。SQLite 不单独存 `current_phase` 或 `has_mistake_on_current`。恢复时固定从 `testing` 阶段展示 `dynamic_queue[current_index]` 卡片，并把“本题是否已答错”视为仅存在于当前内存态的瞬时标记。这意味着：若用户在"刚答错、等待重试"瞬间退出，恢复后该卡重新计为未答题——轻微的 UX 代价，换来状态模型简洁、无歧义。

客户端 `LearningSession` 模型原有 `wordsPayload` 字段，改为 `dataPayload`，对应 SQLite 的 `data_payload` 列。

**服务端**保持不变：

- `user_learning_sessions.words_payload` — 只存单词学习数据，名字准确，无需改名
- `user_review_sessions.items` — 存创建时的原始题目 items，不新增额外 payload 字段

## 离线策略

写操作失败时显示错误提示 + 重试按钮，不强制退出 App。

**各页面网络依赖说明：**

| 页面             | 网络是否必须                     | 失败时行为                                           |
| ---------------- | -------------------------------- | ---------------------------------------------------- |
| kana 图表页      | 必须（需拉取 `/me/kana-states`） | 报错 + 要求重试，不展示空进度                        |
| kana 笔顺 / 音频 | 不需要（本地 seed DB）           | 正常打开                                             |
| 单词学习         | 创建 session 时必须              | 网络失败提示重试；已有本地 active session 可直接恢复 |
| 复习             | 创建 session 时必须              | 网络失败提示重试；已有本地 active session 可直接恢复 |

## 假名数据分层

```
假名内容（本地，不变）        假名状态（云端，多设备共享）
kana_letters (107 条)   +    user_kana_states (GET /me/kana-states)
kana_audio                   ↑ 进入页面时拉取一次
kana_stroke_order            客户端合并渲染带进度的假名列表
```

> 当前文档以现有本地 / 云端表结构为准：假名内容的正式来源是客户端 `assets/database/breeze_jp.sqlite` 中的 `kana_letters` / `kana_audio` / `kana_stroke_order`；云端正式状态表为 `user_kana_states`。`kana_review` 的题目 payload 以会话接口返回结果为准，不再在本文中把云端 `kana_letters` 视为正式内容表。

## 三种数据的读取路径

| 数据类型 | 内容来源     | 状态来源              | 合并方式    |
| -------- | ------------ | --------------------- | ----------- |
| 单词     | API 即时获取 | API 云端直读          | 无需合并    |
| 语法     | API 即时获取 | API 云端直读          | 无需合并    |
| 假名     | 本地 seed DB | API `/me/kana-states` | 客户端 JOIN |

## kana detail 页契约

删除 `kana_examples` 和 `kana_learning_state` 后，kana detail 页的数据来源变更如下：

| 数据项                                        | 来源                             | 备注                                                  |
| --------------------------------------------- | -------------------------------- | ----------------------------------------------------- |
| 字符信息（kana_char、romaji、script_kind 等） | 本地 seed DB `kana_letters`      | 离线可用                                              |
| 笔顺 SVG                                      | 本地 seed DB `kana_stroke_order` | 离线可用                                              |
| 音频                                          | 本地 seed DB `kana_audio`        | 离线可用                                              |
| 学习状态（mastered / learning / 复习时间）    | `/me/kana-states` 内存缓存       | 进入假名图表页时已拉取，detail 从内存读               |
| 例句                                          | **已移除**                       | `kana_examples` 表删除；kana detail UI 不展示例句区块 |

> kana detail 页不单独发起网络请求。学习状态来自图表页已拉取的 `/me/kana-states` 缓存（内存），若用户直接深链进入 detail 页而缓存为空，则不展示学习状态（仅展示字符/笔顺/音频）。

## 实施清单（一次完整切换）

本方案**一次性**完成所有改造，不保留过渡中间状态。

**服务端**

- 新增 `user_learning_sessions` 表，并扩展 `user_review_sessions` 以支持 `kana` 类型
- 新增唯一索引（`idx_learning_sessions_active_book`、`idx_review_sessions_active_kind`）
- 新增一组端点（learn/review session CRUD、grammar/kana states、grammars 列表，详见上方端点表）
- 修改 `favorites/words/toggle` 契约（移除 `book_id` 参数）
- 修改 `me/home-summary` 响应（新增 `kana_mastered_count`）
- 修改 `words/:id` 响应（新增单词级 `is_favorited` 和每条 example 的 `is_favorited`，需认证，未登录返回 false）
- 废弃 `POST /sync/checkpoint` 及 `sync_checkpoint()` RPC 函数
- 删除 `user_profiles.active_device_id` 列
- 删除 `sync_mutation_receipts`、`user_sync_events` 表（如存在）

**客户端**

- 迁移本地 `learning_sessions` 表到目标 schema（见列清单）
- 删除所有本地内容表和用户状态表（见"客户端本地 SQLite"删除列表）
- 删除 `SyncSchedulerCommand`（90s 定时器）
- 删除 `scheduleCheckpoint()` 所有调用点（含 favorites、grammar 写操作后的调用）
- 删除 `syncDisplacedProvider`
- Home 改为调用 `/me/home-summary`，删除本地 home 投影查询
- 收藏写操作改为只传 `word_id`，删除 `resolveBookIdForWord()` 及其对 `lesson_word_map`/`study_words` 的依赖
- 收藏状态读取：`wordFavoriteStateProvider` / `wordExampleFavoriteStateProvider` 改为从 `/words/:id` 返回的 `is_favorited` 字段初始化，不再查本地 `user_word_favorites`/`user_word_example_favorites`；toggle 操作后直接翻转内存状态，无需回查本地表
- 例句收藏页（`ExampleFavoritesPage`）：`WordExampleFavoriteButton` 不走 `wordExampleFavoriteStateProvider`，直接以 `is_favorited = true` 初始化（列表中每条记录按定义均为已收藏）；取消收藏后本地移除该列表项
- 收藏、单词本、语法本、单词详情等读路径改为远端 API（`/me/word-book`、`/me/grammar-book`、`/me/example-favorites`、`/words/:id`）
- books/words/grammars 页面改为 API 即时获取，不再读本地 SQLite
- **启动/认证阶段**：删除 `AppBootstrapCommand` 中的 `checkpointForCurrentUser()`、`bookSyncCommand.syncBooks()`、`wordSyncCommand.syncUpdatedWords()` 调用；删除 `AuthController._prepareAuthenticatedHome()` 和 `AuthController.updateDisplayName()` 中的 `checkpointForCurrentUser()` 调用；启动和登录后只做 `ensureActiveUser`，首页数据改为进入首页后按需调用 `/me/home-summary`
- **选书页**：删除 `BookSelectionController` 对本地 `books` 表的依赖，改为直接 `GET /api/v1/books`；删除 `BookSyncCommand`、`WordSyncCommand`
- **Word Learn 主链路**：`LearnController.startLearning()` / `_startNewBatch()` 改为仅通过 `POST /api/v1/learn/sessions {book_id}` 创建或复用 active session，完成时改接 `POST /api/v1/learn/sessions/:id/complete`；`continueNextBatch()` 改为再次调用 `POST /api/v1/learn/sessions {book_id}` 获取下一批
- **Word Learn 旧 next/cursor fallback 清理**：删除 `VocabRemoteQuery.fetchUserNextWords()`、`VocabRemoteQuery.fetchNextWords()` 及其对已废弃 `GET /api/v1/learn/books/:id/next` 的依赖；删除 `_bookQuery.isBookAvailable()`、本地 `book_progress.currentSortCursor` fallback 与基于本地 cursor 的下一批可用性判断
- **Word Review 旧链路**：删除 `StudyRemoteQuery.fetchWordReviewSession()`（旧 `GET /review/words/session`）、`ReviewSessionRemoteCommand.saveWordSession()`、`ReviewSessionRemoteCommand.completeWordSession()`；`WordReviewController` 的 bootstrap 改接 `POST /review/sessions {kind:"word"}`，完成改接 `POST /review/sessions/:id/complete`，恢复只从本地 `data_payload` 读，不再消费远端 `currentPhase`/`hasMistakeOnCurrent`
- **Word Review 本地 SRS 写回**：删除 `WordReviewController.submitObjectiveAnswer()` 中对 `WordCommand.onWordReviewed()` 的调用；评分结果仅追加到本地 `answered_results`，complete 成功后统一提交 SRS；首页统计刷新从 complete 成功回调触发，不再依赖旧本地状态表更新触发
- **Grammar 学习页**：`GrammarController.loadMoreGrammars()` 改为调用 `GET /api/v1/grammars?exclude_ids=...&unlearned_only=true`，删除对旧 `grammar-learning/queue` 端点的依赖
- **文章列表页**：`ArticleListController.loadArticles()` 删除 `articleQueryProvider.getArticles()` + `articleSyncCommandProvider.syncArticles()` 的本地优先流程，改为直接 `GET /api/v1/articles`
- **文章详情/音频页**：`ArticleAudioController.loadArticle()` 删除 `articleQueryProvider.getArticleById()` + `articleSyncCommandProvider.syncArticleDetail(articleId)` + 回读 SQLite 的流程，改为直接 `GET /api/v1/articles/:id`
- **文章旧链路清理**：删除 `ArticleSyncCommand`、`ArticleQuery` 及其对本地 `articles` / `article_details` 表的依赖
