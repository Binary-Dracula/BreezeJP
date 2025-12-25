---
inclusion: always
---

# Architecture Freeze Checklist

## Freeze Status

✅ **Architecture Status: FROZEN**

- Checked at: 2025-12-23
- Scope: Full project
- Notes: All checklist items verified against current codebase

## 冻结声明

当且仅当以下所有检查项为 ✅ 时，BreezeJP 的架构被视为 **Frozen**。

Frozen 状态下：

- ❌ 不允许因“代码更顺手 / 少写一层 / 图方便”而调整架构
- ✅ 仅允许因**新增明确业务能力**而扩展架构
- 🔁 所有架构级调整必须先修改 steering 文档，再修改代码

## 冻结检查清单

### Controller 层

- [x] Controller 未 import Repository
- [x] Controller 未 import AppDatabase / Database
- [x] Controller 仅调用 Command / Query / Analytics
- [x] Controller 不包含 SQL / rawQuery / rawInsert
- [x] Controller 不直接写 daily_stats / study_logs / kana_logs

### Repository 层

- [x] Repository 仅包含单表 CRUD
- [x] Repository 不包含 join / count / group by
- [x] Repository 不包含业务语义（如 mark / submit / ensure）
- [x] Repository 不返回 Map / List<Map>
- [x] Repository 不暴露 Database

### Query / Analytics 层

- [x] Query / Analytics 只读
- [x] Query / Analytics 通过 databaseProvider 注入 Database
- [x] Query / Analytics 不使用 AppDatabase.instance
- [x] Query / Analytics 返回 DTO / Model（非 Map）
- [x] Analytics 不写任何状态

### Command 层

- [x] 所有写操作只发生在 Command
- [x] Command 不返回 Map / SQL 原始结果
- [x] 多表写 / 事务仅存在于 Command
- [x] daily_stats / study_logs 只由 Command / Session 写入

### Session 架构

- [x] Feature 不直接写 daily_stats
- [x] Feature 不直接写 study_logs
- [x] 所有学习 / 复习统计经由 Session
- [x] 统计链路为：
      SessionStatPolicy → SessionStatAccumulator → flush → DailyStatCommand.applySession
- [x] SessionLifecycleGuard 保证 flush exactly-once

### Active User

- [x] ActiveUserQuery 只读
- [x] ActiveUserCommand 负责创建 / ensure / 切换
- [x] 不存在“读时写”的 Provider

### Debug

- [x] Debug 不 import AppDatabase / Database
- [x] Debug 不 import Repository
- [x] Debug 仅通过 Command / Query 操作数据
- [x] Debug Command 不被 Feature 调用

### 文档一致性

- [x] structure.md 与当前代码目录一致
- [x] database.md 与数据访问规则一致
- [x] tech.md 与实际技术栈一致
- [x] 文档中不存在代码已禁止的示例

## Freeze 判定

- 所有检查项为 ✅ → Architecture = FROZEN
- 任一检查项为 ❌ → Architecture = NOT READY

## 允许破冰的条件（Exception）

以下情况允许调整架构：

- 新增一种此前不存在的业务形态（例如新学习模式）
- 新增跨模块的长期能力（例如多用户 / 云同步）
- 性能瓶颈已被明确量化，且无法通过现有层级解决

破冰流程：

1. 先更新 steering 文档
2. 再修改代码
3. 在变更说明中明确指出破坏了哪一条 Freeze 规则

### Note on Historical Statistics

Learning analytics rules in `learning_analytics.md`
apply to all real-time, state-based statistics.

Existing historical statistics based on daily_stat
or study_log are event-driven and are not yet aligned
with the state-based analytics model.

Do not refactor historical statistics until a
dedicated migration plan is defined.
