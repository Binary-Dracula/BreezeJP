---
inclusion: always
---

# Architecture Freeze（架构冻结文档）

## 一、Freeze 状态声明

✅ **Architecture Status：FROZEN**

- 冻结时间：2025-12-23  
- 冻结范围：全项目（BreezeJP）  
- 冻结依据：以下所有检查项与规则均已与当前代码库核对一致

---

## 二、冻结原则（最高优先级）

当且仅当以下所有检查项为 ✅ 时，BreezeJP 的架构被视为 **Frozen**。

在 Frozen 状态下：

- ❌ **禁止** 因“写起来更顺 / 少写一层 / 图方便”而调整架构
- ❌ **禁止** 为短期功能直接破坏既定层级边界
- ✅ **仅允许** 因“新增明确业务能力”而扩展架构
- 🔁 **任何架构级变更**，必须遵循：
  1. 先修改 steering 文档  
  2. 再修改代码  
  3. 明确指出破坏或调整了哪一条 Freeze 规则  

---

## 三、架构冻结检查清单（Architecture Checklist）

### 1️⃣ Controller 层

- [x] Controller 不 import Repository
- [x] Controller 不 import AppDatabase / Database
- [x] Controller 仅调用 Command / Query / Analytics
- [x] Controller 不包含 SQL / rawQuery / rawInsert
- [x] Controller 不直接写 daily_stats / study_logs / kana_logs

---

### 2️⃣ Repository 层

- [x] Repository 仅包含单表 CRUD
- [x] Repository 不包含 join / count / group by
- [x] Repository 不包含业务语义（如 mark / submit / ensure）
- [x] Repository 不返回 Map / List<Map>
- [x] Repository 不暴露 Database 实例

---

### 3️⃣ Query / Analytics 层

- [x] Query / Analytics 为只读
- [x] Query / Analytics 通过 databaseProvider 注入 Database
- [x] Query / Analytics 不使用 AppDatabase.instance
- [x] Query / Analytics 返回 DTO / Model（非 Map）
- [x] Analytics 不写任何状态、不产生副作用

---

### 4️⃣ Command 层

- [x] 所有写操作仅发生在 Command
- [x] Command 不返回 Map / SQL 原始结果
- [x] 多表写入 / 事务仅存在于 Command
- [x] daily_stats / study_logs 仅由 Command / Session 写入

---

### 5️⃣ Session 架构

- [x] Feature 层不直接写 daily_stats
- [x] Feature 层不直接写 study_logs
- [x] 所有学习 / 复习统计经由 Session
- [x] 统计链路固定为：  
      `SessionStatPolicy → SessionStatAccumulator → flush → DailyStatCommand.applySession`
- [x] SessionLifecycleGuard 保证 flush exactly-once

---

### 6️⃣ Active User

- [x] ActiveUserQuery 为只读
- [x] ActiveUserCommand 负责创建 / ensure / 切换
- [x] 不存在“读时写”的 Provider 行为

---

### 7️⃣ Debug 约束

- [x] Debug 不 import AppDatabase / Database
- [x] Debug 不 import Repository
- [x] Debug 仅通过 Command / Query 操作数据
- [x] Debug Command 不被 Feature 调用

---

### 8️⃣ 文档一致性

- [x] structure.md 与当前目录结构一致
- [x] database.md 与数据访问规则一致
- [x] tech.md 与实际技术栈一致
- [x] 文档中不存在代码层面已禁止的示例

---

## 四、Freeze 判定规则

- ✅ 所有检查项为真 → **Architecture = FROZEN**
- ❌ 任一检查项失败 → **Architecture = NOT READY**

---

## 五、允许破冰的条件（Exception）

以下情况允许调整架构（必须明确说明）：

- 新增一种此前不存在的业务形态（例如新的学习模式）
- 新增跨模块、长期存在的能力（例如多用户 / 云同步）
- 已明确量化的性能瓶颈，且无法通过现有层级解决

**破冰流程必须严格遵守：**

1. 更新 steering 文档  
2. 再修改代码  
3. 在变更说明中明确指出破坏或调整的 Freeze 规则  

---

## 六、历史统计的冻结例外说明（重要）

### Historical Statistics Note

- `learning_analytics.md` 中定义的统计规则  
  **仅适用于实时、基于状态（state-based）的统计**

- 现有基于：
  - `daily_stat`
  - `study_log`
  
  的统计逻辑属于 **事件驱动（event-based）模型**

- 两者目前 **语义不一致是已知且被允许的状态**

### 冻结约束

- ❌ 不允许在没有完整迁移方案的前提下  
  “顺手”重构历史统计逻辑
- ❌ 不允许为统一口径而直接修改 daily_stat 统计
- ✅ 历史统计如需调整，必须：
  - 单独制定迁移方案
  - 明确影响范围
  - 明确是否重算历史数据

---

## 七、Word × Kana 学习架构同构冻结（新增）

### 同构声明（冻结）

Word 学习架构 **必须与 Kana 学习架构保持同构**，不允许出现语义或结构分叉。

包括但不限于：

- 学习状态定义
- 状态流转规则
- SRS 参与条件
- 统计口径
- Command / Query / Controller 职责边界

Word 的学习状态写入已由 word_command.dart 落地并冻结。
---

### 学习生命周期（Word）

#### 状态定义

- `seen`：已曝光，尚未进入学习
- `learning`：学习中（参与 SRS）
- `mastered`：已掌握
- `ignored`：已忽略（路径控制状态）

#### 允许的状态转移

- `seen → learning`（**仅限点击「开始学习」按钮**）
- `seen → ignored`
- `ignored → seen`
- `learning → mastered`
- `learning → ignored`
- `mastered → ignored`

#### 明确禁止的状态转移

- ❌ `seen → learning`（任何隐式行为）
- ❌ `ignored → learning`
- ❌ `seen → mastered`

---

### UI 与状态绑定规则（Word）

| 状态 | 开始学习 | 已掌握 | 已忽略 |
|----|--------|--------|--------|
| seen | 显示 | 隐藏 | 显示 |
| learning | 隐藏 | 显示 | 显示 |
| mastered | 隐藏 | 隐藏 | 显示 |
| ignored | 隐藏 | 隐藏 | 显示 |

---

### SRS 与统计继承声明

- Word 学习 **完全继承** `learning_analytics.md` 中的统计与 SRS 规则
- 不允许定义任何 Word 特有的学习统计口径
- SRS 仅允许 `learning` 状态参与

---

### 架构对齐声明

- Word 的 Command / Query / Controller  
  **在结构与语义上必须与 Kana 一一对应**
- 不允许为 Word 单独发明生命周期、捷径或特殊逻辑

---

## 八、最终冻结说明（强约束）

> **本文件中定义的所有规则，  
> 对 Codex、未来代码、未来功能同等生效。**  
>  
> 任何违反本文件的实现，  
> 均视为架构错误，而非实现细节问题。
