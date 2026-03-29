# Plan: 文章 API 拉取 + 增量同步 + 本地缓存 (v3)

开发阶段不做版本兼容。数据流：**API → 本地 SQLite 缓存 → UI**。支持增量同步（`since` 参数）。本地表字段名与 Supabase 一致，类型适配 SQLite。

---

### Phase 0: 数据准备

**目标**：Supabase + R2 上有可测试的文章数据。

1. **设置环境变量** `SUPABASE_SERVICE_KEY`
2. **执行 `upload_to_backend.py`** 上传 3 篇已处理文章到 Supabase（articles + article_details）+ mp3 到 R2
   - 命令：`cd tools/nhk_data_pipeline && python scripts/upload_to_backend.py --force`
3. **验证**：`curl` 调 `/api/v1/health` 确认 Workers 存活；Supabase Dashboard 确认 3 条记录

### Phase 1: 本地 SQLite 建表

**目标**：在预构建的 `assets/database/breeze_jp.sqlite` 中添加文章相关表。

4. **在 .sqlite 中添加两张表**（用 SQLite CLI 或 DB Browser 工具）：

   ```sql
   -- articles（与 Supabase 字段名一致，类型适配 SQLite）
   CREATE TABLE IF NOT EXISTS articles (
       id              TEXT PRIMARY KEY,
       title           TEXT NOT NULL,
       clean_title     TEXT NOT NULL DEFAULT '',
       published_at    TEXT NOT NULL,           -- ISO8601 字符串
       audio_url       TEXT NOT NULL DEFAULT '',
       duration_ms     INTEGER NOT NULL DEFAULT 0,
       sentence_count  INTEGER NOT NULL DEFAULT 0,
       is_archived     INTEGER NOT NULL DEFAULT 0,  -- 0=false, 1=true
       created_at      TEXT NOT NULL DEFAULT '',
       updated_at      TEXT NOT NULL DEFAULT ''
   );
   CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles(published_at DESC);
   CREATE INDEX IF NOT EXISTS idx_articles_updated_at ON articles(updated_at DESC);

   -- article_details
   CREATE TABLE IF NOT EXISTS article_details (
       article_id  TEXT PRIMARY KEY,
       items       TEXT NOT NULL DEFAULT '[]',  -- JSON 字符串
       created_at  TEXT NOT NULL DEFAULT '',
       updated_at  TEXT NOT NULL DEFAULT ''
   );
   ```

5. **新建 `sync_state` 记录** — 在 app_state 表或新增 key-value 方式存储 `articles_last_sync_time`
   - 可复用 SharedPreferences（更轻量）或在 SQLite 中加一个 `sync_metadata` 表

### Phase 2: Model 层重构

**目标**：拆分为 `ArticleSummary`（列表）+ `ArticleDetail`（详情含 items）+ 本地持久化模型。

6. **重构 `Article` → `ArticleSummary`** — 删除 `items` 和 `localAudioPath`，新增 `publishedAt`、`sentenceCount`、`isArchived`、`audioUrl`
   - `lib/data/models/article/article.dart` → 改为 `article_summary.dart`
   - 实现 `fromMap()` / `toMap()` 用于 SQLite 读写
   - 实现 `fromJson()` 用于 API 响应解析

7. **新建 `ArticleDetail`** — `ArticleSummary` 字段 + `items: List<ArticleItem>`
   - `lib/data/models/article/article_detail.dart` (NEW)
   - `fromJson()` 解析 API 详情响应
   - `fromMap()` 从 SQLite 读取（items 列为 JSON 字符串需 `jsonDecode`）

8. **新建 `ArticleListResponse`** — 封装分页响应 `{ data, meta: {total, has_more, cursor, server_time} }`
   - `lib/data/models/article/article_list_response.dart` (NEW)

9. `dart run build_runner build --delete-conflicting-outputs`

### Phase 3: Repository 层（本地 SQLite CRUD）

**目标**：单表 CRUD，符合架构规范 Repository 层。

10. **新建 `ArticleRepository`** — articles 表的 CRUD
    - `lib/data/repositories/article_repository.dart` (NEW)
    - `upsertArticle(ArticleSummary)` — INSERT OR REPLACE
    - `getArticleById(String id)` → `ArticleSummary?`
    - `getAllArticles({int limit, int offset})` → `List<ArticleSummary>`
    - `markArchived(String id)` — 设 `is_archived = 1`

11. **新建 `ArticleDetailRepository`** — article_details 表的 CRUD
    - `lib/data/repositories/article_detail_repository.dart` (NEW)
    - `upsertDetail(String articleId, List<ArticleItem> items)`
    - `getDetailByArticleId(String id)` → items JSON → `List<ArticleItem>`

### Phase 4: 远程数据源（Query 层）

12. **新建 `ArticleRemoteQuery`** — 通过 `DioClient.instance` 调 API
    - `lib/data/queries/article_remote_query.dart` (NEW)
    - `fetchArticles({String? since, int limit, String? cursor})` → `ArticleListResponse`
    - `fetchArticleDetail(String id)` → `ArticleDetail`

13. **新建 `articleRemoteQueryProvider`**
    - `lib/data/queries/article_remote_query_provider.dart` (NEW)

### Phase 5: 同步服务（Command 层）

**目标**：增量同步 — 拉取新/更新的文章 → 写入本地 SQLite。

14. **新建 `ArticleSyncCommand`** — 增量同步写入命令
    - `lib/data/commands/article_sync_command.dart` (NEW)
    - `syncArticles()`:
      1. 读取 `SharedPreferences` 中的 `articles_last_sync_time`（首次为空 → 全量）
      2. 调 `ArticleRemoteQuery.fetchArticles(since: lastSyncTime)`
      3. 遍历返回的 articles → `ArticleRepository.upsertArticle()`
      4. 保存 `meta.server_time` 到 SharedPreferences
      5. 返回新增/更新数量
    - `syncArticleDetail(String id)`:
      1. 调 `ArticleRemoteQuery.fetchArticleDetail(id)`
      2. 写入 `ArticleDetailRepository.upsertDetail()`

15. **新建 `articleSyncCommandProvider`**
    - `lib/data/commands/article_sync_command_provider.dart` (NEW)

### Phase 6: ArticleQuery 改造（本地读取）

**目标**：Query 层只读本地 SQLite，不直接调 API。

16. **改造 `ArticleQuery`** — 从 mock JSON 改为读本地 SQLite
    - `lib/data/queries/article_query.dart`
    - `getArticles()` → 从 `ArticleRepository.getAllArticles()` 返回 `List<ArticleSummary>`
    - `getArticleById(id)` → 从两张表 JOIN 读取 → 返回 `ArticleDetail`

17. **更新 `articleQueryProvider`**
    - `lib/data/queries/article_query_provider.dart`

### Phase 7: Controller + State 层

18. **`ArticleListState`** — `articles` 改为 `List<ArticleSummary>`，新增 `needsLogin` bool、`isSyncing` bool
    - `lib/features/article/state/article_list_state.dart`

19. **`ArticleListController`** — 流程：检查登录 → 同步 → 读本地
    - `lib/features/article/controller/article_list_controller.dart`
    - 未登录 → `needsLogin: true`
    - 已登录 → 调 `ArticleSyncCommand.syncArticles()` → 调 `ArticleQuery.getArticles()` → 更新 state

20. **`ArticleState`** — `article` 类型改为 `ArticleDetail`
    - `lib/features/article/state/article_state.dart`

21. **`ArticleAudioController`** — 适配 `ArticleDetail` + 远程音频
    - `lib/features/article/controller/article_audio_controller.dart`
    - `initArticle()`:
      - 先检查本地 `ArticleQuery.getArticleById(id)` 是否有 items
      - 没有 → 调 `ArticleSyncCommand.syncArticleDetail(id)` → 再读本地
      - 音频：`setUrl('${ApiEndpoints.baseUrl}/api/v1/audio/{id}', headers: {Authorization: Bearer jwt})`

### Phase 8: View 层

22. **`ArticleListPage`** — `needsLogin` 登录引导 UI；`ArticleSummary` 类型；可显示 `publishedAt`、`sentenceCount`
    - `lib/features/article/pages/article_list_page.dart`

23. **`ArticleDetailPage`** — 无需改动（items 在 `ArticleDetail` 中）

24. **新增 l10n 文案** — 登录拦截、同步状态提示

### Phase 9: 清理

25. 删除 `_mockAssetPath`、`rootBundle.loadString` 等 mock 逻辑
26. 删除旧 `article.g.dart`，重新生成

---

### Relevant Files

| 文件                                                            | 操作          | 说明                                              |
| --------------------------------------------------------------- | ------------- | ------------------------------------------------- |
| `assets/database/breeze_jp.sqlite`                              | MODIFY        | 预构建加 articles + article_details 表            |
| `lib/data/models/article/article.dart`                          | MODIFY→RENAME | → `article_summary.dart`，删 items/localAudioPath |
| `lib/data/models/article/article_detail.dart`                   | NEW           | 含 items 的详情模型                               |
| `lib/data/models/article/article_list_response.dart`            | NEW           | API 分页响应                                      |
| `lib/data/repositories/article_repository.dart`                 | NEW           | articles 表 CRUD                                  |
| `lib/data/repositories/article_detail_repository.dart`          | NEW           | article_details 表 CRUD                           |
| `lib/data/queries/article_remote_query.dart`                    | NEW           | API 远程查询                                      |
| `lib/data/queries/article_remote_query_provider.dart`           | NEW           | Provider                                          |
| `lib/data/commands/article_sync_command.dart`                   | NEW           | 增量同步命令                                      |
| `lib/data/commands/article_sync_command_provider.dart`          | NEW           | Provider                                          |
| `lib/data/queries/article_query.dart`                           | MODIFY        | mock → SQLite 读取                                |
| `lib/data/queries/article_query_provider.dart`                  | MODIFY        | 注入依赖                                          |
| `lib/features/article/state/article_list_state.dart`            | MODIFY        | ArticleSummary + needsLogin + isSyncing           |
| `lib/features/article/state/article_state.dart`                 | MODIFY        | → ArticleDetail                                   |
| `lib/features/article/controller/article_list_controller.dart`  | MODIFY        | 登录检查 + 同步 + 读本地                          |
| `lib/features/article/controller/article_audio_controller.dart` | MODIFY        | ArticleDetail + 远程音频                          |
| `lib/features/article/pages/article_list_page.dart`             | MODIFY        | 登录拦截 UI                                       |

### 数据流总结

```
[列表页]
用户打开 → Controller 检查登录 → 已登录 → SyncCommand.syncArticles()
  → RemoteQuery.fetchArticles(since=lastSync) → API
  → Repository.upsertArticle() → SQLite
  → ArticleQuery.getArticles() → 从 SQLite 读 → UI

[详情页]
用户点击 → AudioController.initArticle(id)
  → ArticleQuery.getArticleById(id) → SQLite
  → 无 items → SyncCommand.syncArticleDetail(id)
    → RemoteQuery.fetchArticleDetail(id) → API
    → DetailRepository.upsertDetail() → SQLite
  → 再读 SQLite → UI + setUrl(audio)
```

### Verification

1. **Phase 0**: `curl https://api.binary-dracula.com/api/v1/health` → 200
2. **Phase 0**: Supabase Dashboard 有 3 条 articles 记录
3. **Phase 1**: 用 DB Browser 打开 .sqlite 确认新表存在
4. **全流程**: 已登录 → 列表加载 → 点详情 → 音频播放 → AB 循环正常
5. **增量**: 首次全量同步 → 关闭 app → 后端加一篇新文章 → 再打开 → 只同步 1 篇
6. **未登录**: 列表页显示登录引导
7. **编译**: `build_runner build` + `flutter analyze` 无错误
