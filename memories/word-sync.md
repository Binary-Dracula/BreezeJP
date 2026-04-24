# 单词增量同步功能档案

## 功能概述
App 启动时，用时间戳向 API 请求"最近更新的单词"，覆盖本地已有单词的内容（用户尚未下载的跳过）。确保管理员在后台修改的单词数据能同步到已安装 App 的用户。

---

## 数据流

```
App 启动 → Splash → AppBootstrapCommand.run()
  → WordSyncCommand.syncUpdatedWords()
    → 读 SharedPreferences: words_last_sync_time
    → GET /api/v1/words/sync?since=<timestamp>
    → Worker 查 Supabase: words WHERE updated_at > since (limit 500)
    → fetchFullDetailsBatch() 拿完整数据
    → 客户端遍历: 本地有该 word_id → UPDATE 覆盖; 没有 → 跳过
    → 从响应 meta.server_time 更新 SharedPreferences
```

---

## 1. Workers API

文件：`api/workers/src/routes/vocab.ts`

新增函数：`export async function handleWordSync(request, env, auth)`

- 读取 `?since=` query param（ISO 时间戳）
- 若无 since，返回空 data + 当前 server_time
- 查 Supabase：`GET /words?updated_at=gt.{since}&order=updated_at.asc&limit=500`
- 调 `fetchFullDetailsBatch()`（已改为 export）拿完整数据
- 返回：`{ data: [...VocabFullDetail], meta: { count, server_time } }`

注册位置：`api/workers/src/index.ts`（JWT 认证区块内）

```typescript
import { handleBookList, handleNextWords, handleWordSync } from './routes/vocab';
// ...
// GET /api/v1/words/sync?since=<ISO>
if (path === '/api/v1/words/sync') {
  return handleWordSync(request, env, auth);
}
```

---

## 2. Flutter 层

### 端点常量
`lib/core/network/api_endpoints.dart`
```dart
static const String wordSync = '/api/v1/words/sync';
```

### Command
`lib/data/commands/word_sync_command.dart`

- SharedPreferences key：`words_last_sync_time`
- 首次运行（无时间戳）：跳过同步，写入当前时间作为基线
- 正常流程：GET 拉取 → 解析 `List<WordDetail>` → 事务内逐条检查本地是否存在 → 存在则 `INSERT OR REPLACE` words + word_details + delete/re-insert word_examples → 写入 server_time
- 返回更新数量

`lib/data/commands/word_sync_command_provider.dart`
```dart
final wordSyncCommandProvider = Provider<WordSyncCommand>((ref) {
  final db = ref.read(databaseProvider);
  return WordSyncCommand(db);
});
```

### 集成启动流程
`lib/data/commands/app_bootstrap_command.dart`
```dart
try {
  await _ref.read(wordSyncCommandProvider).syncUpdatedWords();
} catch (e) {
  logger.error('[Bootstrap] Word sync failed, skipping', e);
}
```

---

## 3. 验证流程

1. 在 Supabase 手动修改一个已有单词的 `primary_meaning`（自动触发 `updated_at` 更新）
2. 冷启动 App，日志出现 `[WordSync] 同步完成，更新 1 条`
3. 进入学习页确认新释义已生效
4. 再次冷启动，确认该单词不再被同步（`since` 已更新）

---

## 关键注意事项

- **首次运行不拉全量**：没有 lastSync 时直接跳过，避免拉几千条数据；写入当前时间作为基线，之后只同步增量。
- **server_time 由服务端返回**：避免客户端时钟偏差导致漏同步。
- **每次请求后都更新时间戳**：无论有无更新，都用响应中的 server_time 覆盖本地时间戳。
- **word_examples 没有 updated_at**：直接改 word_examples 不会触发 words.updated_at 更新，同步会漏掉。如需修复，在 Supabase 加触发器：改 word_examples 时自动 touch `words.updated_at`。
- 失败静默处理（try/catch），不阻断启动流程。
