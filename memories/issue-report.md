# Issue Report 功能档案

## 功能概述

用户在学习页（单词 / 语法）发现问题时，点击 🚩 按钮上报，内容进入 Supabase，管理员在 Admin 面板处理。

---

## 1. 数据库层（Supabase）

表名：`issue_reports`

```sql
CREATE TABLE issue_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  type        TEXT NOT NULL,          -- 'word' | 'grammar'
  description TEXT NOT NULL,
  snapshot    JSONB,                  -- 上报时的词条/语法完整快照
  status      TEXT NOT NULL DEFAULT 'open',  -- 'open' | 'resolved' | 'wont_fix'
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

RLS：用户只能 INSERT 自己的记录；管理员 Service Role 可全量读写。

---

## 2. Workers API

文件：`api/workers/src/routes/issues.ts`

路由：`POST /api/v1/issues`（需要 JWT 认证）

注册位置：`api/workers/src/index.ts`

```typescript
// index.ts 中
import { handleCreateIssue } from "./routes/issues";
// ...
if (path === "/api/v1/issues" && request.method === "POST") {
  return handleCreateIssue(request, env, auth);
}
```

payload 示例：

```json
{
  "type": "word",
  "description": "释义有误，应为……",
  "snapshot": {
    /* word.toMap() + richContent.toJsonString() */
  }
}
```

---

## 3. Flutter 层

### 端点常量

`lib/core/network/api_endpoints.dart`

```dart
static const String issues = '/api/v1/issues';
```

### Command

`lib/data/commands/issue_report_command.dart`

- POST 到 `ApiEndpoints.issues`
- 字段：`type`, `description`, `snapshot`

`lib/data/commands/issue_report_command_provider.dart`

```dart
final issueReportCommandProvider = Provider<IssueReportCommand>((ref) { ... });
```

### Widget

`lib/features/common/widgets/issue_report_sheet.dart`

- `ConsumerStatefulWidget`，底部弹出 Sheet
- 静态方法 `IssueReportSheet.show(context, type, snapshot)`
- 包含描述文本框 + 提交按钮

### 调用点

**单词学习页** `lib/features/learn/pages/learn_page.dart`

```dart
// AppBar 右侧 IconButton
IconButton(
  icon: const Icon(Icons.flag_outlined),
  onPressed: () => IssueReportSheet.show(
    context,
    type: 'word',
    snapshot: {
      ...wordDetail.word.toMap(),
      'rich_content': wordDetail.richContent.toJsonString(),
    },
  ),
)
```

**语法学习页** `lib/features/grammar/pages/grammar_learning_page.dart`

```dart
// AppBar actions 中
IconButton(
  icon: const Icon(Icons.flag_outlined),
  onPressed: () => IssueReportSheet.show(
    context,
    type: 'grammar',
    snapshot: {
      'grammar': grammar.toMap(),
      'meanings': ...,
      'contexts': ...,
      'examples': ...,
    },
  ),
)
```

---

## 4. Admin 面板

路径：`admin/`（React + Vite + TypeScript）

部署：Cloudflare Pages，项目名 `breezejp-admin`

地址：

- `https://breezejp-admin.pages.dev`
- `https://admin.binary-dracula.com`（自定义域名）

部署命令（必须加 `--branch main`）：

```bash
cd admin && npm run build
npx wrangler pages deploy dist --project-name breezejp-admin --branch main --commit-dirty=true
```

功能：

- 登录（Supabase Auth，管理员账号）
- 问题列表，支持按 type / status 筛选
- 问题详情，含 snapshot 展示
- 状态修改（open → resolved / wont_fix）

---

## 5. 验证流程

1. App 内点击 🚩 → 填写描述 → 提交
2. Supabase `issue_reports` 表出现新记录
3. `https://admin.binary-dracula.com` 登录后可见该条记录
4. Admin 面板修改 status → Supabase 更新

---

## 关键注意事项

- `wordDetail.richContent.toJsonString()` —— 方法在 `WordRichContent` 上，不在 `WordDetail` 上
- Admin 部署**必须带 `--branch main`**，否则是 preview 部署，自定义域名不生效
- RLS 策略：普通用户只能写，不能读他人记录
