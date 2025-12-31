---
inclusion: always
---

# Architecture Freeze（架构冻结文档）

## 一、Freeze 状态声明

✅ **Architecture Status：FROZEN**

* 冻结时间：2025-12-23
* 冻结范围：全项目（BreezeJP）
* 冻结依据：

  * 学习数据模型（study_words / study_logs / daily_stats）
  * 行为语义（firstLearn / review / mastered / ignored）
  * 统计口径（今日学习 / 连续学习 / 累计掌握）
    均已完成**语义级对齐并确认无歧义**

---

## 二、冻结原则（最高优先级）

当且仅当以下所有检查项为 ✅ 时，BreezeJP 的架构被视为 **Frozen**。

在 Frozen 状态下：

* ❌ **禁止** 因“写起来更顺 / 少写一层 / 图方便”而调整架构
* ❌ **禁止** 以状态推导事件，或以事件反推状态
* ❌ **禁止** 混用 state-based 与 event-based 统计模型
* ✅ **仅允许** 因“新增明确业务能力”而扩展架构
* 🔁 **任何架构级变更**，必须遵循：

  1. 先修改 steering / freeze 文档
  2. 再修改代码
  3. 明确指出破坏或调整了哪一条 Freeze 规则

---

## 三、核心数据模型冻结（关键新增）

### 1️⃣ study_words ——「状态表（State-based）」

**唯一职责：描述某个单词在当前用户下的“当前状态”**

* 一词一行
* 无历史
* 可被覆盖更新

#### 状态定义

* `seen`：已曝光（PageView 展示即进入）
* `learning`：学习中（参与 SRS）
* `mastered`：已掌握
* `ignored`：已忽略（路径控制状态）

#### 明确声明

* ❌ study_words **不表示学习事件**
* ❌ study_words **不表示是否“新学”**
* ❌ study_words **不参与任何统计口径**
* ✅ study_words 只回答一个问题：
  **“现在，这个词对这个用户是什么状态”**

---

### 2️⃣ study_logs ——「行为表（Event-based）」

**唯一职责：记录用户的“离散行为事件”**

* 一词多条
* 只追加，不覆盖
* 严格按时间排序

#### firstLearn 的冻结语义（重要）

> **firstLearn = 用户第一次明确点击「加入复习 / 开始学习」的行为事件**

冻结规则：

* firstLearn **只与用户行为有关**
* firstLearn **与 study_words 当前状态无关**
* firstLearn **不关心 seen / learning / mastered**
* 同一 `(user_id, word_id)`
  **最多只允许一条 firstLearn log**

#### 明确禁止

* ❌ 不允许用 study_words 的状态变化来“推导” firstLearn
* ❌ 不允许在 seen → learning 的状态迁移中“顺手写 firstLearn”
* ❌ 不允许因为 study_words 不存在而“补写 firstLearn”

---

### 3️⃣ daily_stats ——「统计表（Analytics）」

**唯一职责：存储“已确认口径”的统计结果**

#### 今日学习（new_learned_count）

冻结定义：

> **今日学习 = 今日产生的 firstLearn 事件数量**

规则：

* ✅ 唯一来源：`study_logs.log_type = firstLearn`
* ✅ 写入时机：firstLearn **成功插入时同步写入**
* ❌ 不从 study_words 推导
* ❌ 不从 session / duration / review 推导
* ❌ 不允许回放 logs 重新计算

---

## 四、架构冻结检查清单（Architecture Checklist）

### 1️⃣ Controller 层

* [x] Controller 不 import Repository
* [x] Controller 不 import AppDatabase / Database
* [x] Controller 仅调用 Command / Query
* [x] Controller 不直接写 study_words / study_logs / daily_stats

---

### 2️⃣ Repository 层

* [x] Repository 仅包含单表 CRUD
* [x] Repository 不包含业务语义（firstLearn / submit / ensure）
* [x] Repository 不返回 Map / SQL 原始结构

---

### 3️⃣ Query / Analytics 层

* [x] Query 为只读
* [x] Query 不写任何状态
* [x] Query 不推导“新学 / firstLearn”

---

### 4️⃣ Command 层（重点修订）

* [x] **firstLearn 只允许在“加入复习”语义入口写入**
* [x] study_words 的状态迁移与 study_logs 完全解耦
* [x] Command 不以 state 推导 event
* [x] Command 不以 event 反写 state（除非明确业务语义）

---

### 5️⃣ Session 架构（统计冻结）

* [x] Session **不参与 firstLearn**
* [x] Session 只处理 review / duration / kanaReview
* [x] Session 不修改 new_learned_count

---

### 6️⃣ Debug 约束

* [x] Debug 只读 Query
* [x] Debug 不推导统计
* [x] Debug 页面展示的“今日学习”
  **必须与 daily_stats 完全一致**

---

## 五、Word 学习生命周期冻结（修订）

### 状态迁移规则（最终）

| 行为          | study_words   | study_logs      |
| ----------- | ------------- | --------------- |
| PageView 展示 | seen（若不存在则创建） | ❌               |
| 点击加入复习      | learning      | firstLearn（仅一次） |
| 播放音频        | 不变            | ❌               |
| 一键掌握        | mastered      | mastered log    |
| 点击忽略        | ignored       | ignored log     |

---

### 明确禁止的隐式行为

* ❌ PageView 不得写 firstLearn
* ❌ 自动 seen → learning 不得写 firstLearn
* ❌ SRS / review 不得补写 firstLearn

---

## 六、Kana × Word 同构冻结（保持不变）

* Kana 的 firstLearn / 学习统计
  **必须与 Word 完全同构**
* 不允许任何一侧采用 state-based，新的一侧采用 event-based

---

## 七、最终冻结说明（强约束）

> **study_words 是状态，不是历史**
> **study_logs 是事件，不是状态**
> **daily_stats 是结果，不是推导过程**

> **任何混用三者语义的实现，
> 均视为架构错误，而非实现细节问题。**
