# Issue Report 功能档案

## 功能概述

已登录用户可在单词学习页、单词详情页、语法学习页提交问题上报。App 通过 Workers `POST /api/v1/issues` 写入 Supabase `issue_reports`，Admin 面板使用 service role 做全量查看和处理。

---

## 1. 数据库层（Supabase）

表名：`issue_reports`

```sql
CREATE TABLE IF NOT EXISTS issue_reports (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL,
  content_type      TEXT NOT NULL CHECK (content_type IN ('word', 'grammar')),
  content_id        TEXT NOT NULL,
  content_snapshot  JSONB NOT NULL,
  message           TEXT,
  status            TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'resolved', 'ignored')),
  admin_note        TEXT,
  resolved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

RLS：

- 已登录用户可以 `INSERT` 自己的记录。
- 已登录用户可以 `SELECT` 自己提交的记录。
- 管理后台使用 `service_role` 绕过 RLS 进行全量读写。

---

## 2. Workers API

文件：`api/workers/src/routes/issues.ts`

路由：`POST /api/v1/issues`（需要 JWT 认证）

请求体字段：

- `content_type`：`word` 或 `grammar`
- `content_id`：单词 UUID 或语法 ID 字符串
- `content_snapshot`：提交时的完整快照
- `message`：用户补充说明，可为空

payload 示例：

```json
{
  "content_type": "word",
  "content_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "content_snapshot": {
    "word": {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "word": "高校"
    },
    "rich_content": "{\"meanings\": []}"
  },
  "message": "首要释义需要调整"
}
```

校验与响应：

- 缺少 `content_type` / `content_id` / `content_snapshot` 时返回 `400 BAD_REQUEST`
- `content_type` 只接受 `word` 或 `grammar`
- 成功时返回 `201` 和 `{ "success": true }`

---

## 3. Flutter 层

### 端点常量

`lib/core/network/api_endpoints.dart`

```dart
static const String issues = '/api/v1/issues';
```

### Command

`lib/data/commands/issue_report_command.dart`

```dart
Future<void> reportIssue({
  required String contentType,
  required String contentId,
  required Map<String, dynamic> contentSnapshot,
  String? message,
})
```

发送字段：`content_type`、`content_id`、`content_snapshot`、`message`。

### Widget

`lib/features/common/widgets/issue_report_sheet.dart`

- `ConsumerStatefulWidget`，通过 BottomSheet 展示
- 静态方法：

```dart
IssueReportSheet.show(
  context: context,
  ref: ref,
  contentType: 'word',
  contentId: wordId,
  contentSnapshot: snapshot,
  displayTitle: title,
);
```

### 当前调用点

- `lib/features/learn/pages/learn_page.dart`
- `lib/features/word_detail/pages/word_detail_page.dart`
- `lib/features/grammar/pages/grammar_learning_page.dart`

单词上报示例：

```dart
IssueReportSheet.show(
  context: context,
  ref: ref,
  contentType: 'word',
  contentId: wordDetail.word.id,
  contentSnapshot: {
    'word': wordDetail.word.toMap(),
    'rich_content': wordDetail.richContent.toJsonString(),
  },
  displayTitle: wordDetail.word.word,
);
```

语法上报示例：

```dart
IssueReportSheet.show(
  context: context,
  ref: ref,
  contentType: 'grammar',
  contentId: detail.grammar.id.toString(),
  contentSnapshot: {
    'grammar': detail.grammar.toMap(),
    'meanings': detail.meanings.map((m) => m.toMap()).toList(),
    'contexts': detail.contexts.map((c) => c.toMap()).toList(),
    'examples': detail.examples.map((e) => e.toMap()).toList(),
  },
  displayTitle: detail.grammar.title,
);
```

---

## 4. Admin 面板

主要文件：

- `admin/src/pages/IssueListPage.tsx`
- `admin/src/pages/IssueDetail.tsx`

当前行为：

- 列表页按 `status` 过滤，状态值为 `open` / `resolved` / `ignored`
- 详情页展示并编辑 `content_snapshot`
- 可保存修改到实际内容表后标记 `resolved`
- 也可仅更新状态为 `resolved` 或 `ignored`
- `admin_note` 和 `resolved_at` 与状态更新一起写回 `issue_reports`

实际回写目标：

- `word`：`words` + `word_details`
- `grammar`：`grammars` + `grammar_meanings` + `grammar_examples`

---

## 5. 验证流程

1. App 内点击旗帜按钮，填写说明并提交。
2. Supabase `issue_reports` 表出现新记录。
3. Admin 列表页能看到该记录，状态初始为 `open`。
4. 在详情页修改数据或直接变更状态，`issue_reports.status` / `admin_note` / `resolved_at` 更新。

---

## 关键注意事项

- `content_id` 在接口层统一按字符串传输；语法 ID 提交时要 `toString()`。
- `message` 允许为空；真正必填的是 `content_type`、`content_id`、`content_snapshot`。
- `content_snapshot` 是提交时证据快照，不是直接展示给客户端回读的正式内容源。
- 状态值没有 `wont_fix`；当前忽略态统一使用 `ignored`。
