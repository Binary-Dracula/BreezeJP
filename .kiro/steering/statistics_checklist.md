---
inclusion: always
---

# 统计相关改动 Checklist（封板）

> **适用范围**
> 任何涉及 **学习统计 / 学习时长 / 今日学习 / 今日复习 / streak / 掌握数 / daily_stats / study_logs** 的改动
>
> **以下任一项未通过 → 不允许合并**

---

## 一、统计模型前置确认（Model Sanity Check）

在开始任何改动前，必须确认以下模型认知 **100% 成立**：

* [ ] `study_words / kana_learning_state`
  **只描述“当前状态”**
* [ ] `study_logs`
  **只描述“用户行为事件”**
* [ ] 两者 **不互为推导来源**
* [ ] 所有 Dashboard / Analytics 数值
  **都有唯一合法来源**

> ❗ 若任何一条需要“解释”“折中”“临时理解”
> → 立即停止，回退改动

---

## 二、数据来源校验（Source of Truth）

### ⏱ 学习时长（Time）

**定义回顾（冻结）**
学习时长 = 用户处于“学习页面前台可见状态”的累计时间

#### Checklist

* [ ] **唯一来源** 是否仍为 `PageDurationTracker`
* [ ] 是否 **只写入** `daily_stats.total_time_ms`
* [ ] 是否 **完全没有** 从以下来源计算时间：

  * `study_logs`
  * Session / Accumulator
  * 行为参数 `durationMs`
* [ ] 页面驻留 < **最小阈值（2000ms）** 是否被静默丢弃
* [ ] App 前后台切换是否：

  * pause → flush
  * resume → 重新计时
* [ ] 跨页面跳转是否不会产生重复计时

---

### 📅 今日学习 / 今日复习（Daily）

**定义回顾（冻结）**

* 今日学习 = 当天产生的 `firstLearn` 行为数
* 今日复习 = 当天产生的 `review` 行为数
* **与当前状态无关**

#### Checklist

* [ ] UI 是否 **只读取** `daily_stats`

  * `new_learned_count`
  * `review_count`
* [ ] 是否 **完全没有**：

  * 从 logs 回放计算“今日”
  * 从状态表（`study_words / kana_learning_state`）反推“今日”
* [ ] 写入是否发生在：

  * **用户行为发生的当下**
  * **增量更新（+1）**
* [ ] 是否不存在任何：

  * 跨天补算
  * 重算
  * 延迟修正
* [ ] 是否明确接受：

  * “今日学习 = 0，但存在 learning 状态”
    属于 **合法结果**

---

### 🧠 累计掌握（Mastered）

**定义回顾（冻结）**

累计掌握 = 当前状态为 `mastered` 的实体数量（去重）

#### Checklist

* [ ] 是否 **只读取** 状态表：

  * `study_words.user_state = mastered`
  * `kana_learning_state.learning_status = mastered`
* [ ] 是否 **完全未使用**：

  * `daily_stats`
  * `study_logs`
* [ ] 是否为 **去重后的实体数**（不是次数、不是历史）

---

### 🔥 连续学习（Streak）

**定义回顾（冻结）**

某一天只要“发生过任意有效学习行为”，即视为学习日。

#### Checklist

* [ ] 是否 **只依赖** `daily_stats`
* [ ] 当天或昨天是否满足任意条件之一即成立：

  * `new_learned_count > 0`
  * `review_count > 0`
  * `total_time_ms > 0`
* [ ] 是否使用 **gaps-and-islands（非递归 CTE）**
* [ ] 是否 **完全没有** 从 logs 计算 streak

---

## 三、写入路径校验（Write Path）

### daily_stats 写入

#### Checklist

* [ ] 是否 **只通过** `DailyStatCommand`
* [ ] 是否满足以下严格分工：

  * `applyTimeOnlyDelta`

    * 只更新 `total_time_ms`
  * `applyLearningDelta`

    * 只更新 `new_learned_count / review_count`
    * **不更新** `total_time_ms`
* [ ] 是否不存在以下反模式：

  * 页面直接写 DB
  * Repository 直接 `update daily_stats`
  * Analytics / Query 层写数据
  * 全量覆盖（copyWith + update）

---

### 行为日志（study_logs）

**角色定义（冻结）**

> 行为日志 = 用户做了什么
> 不是统计表，不是状态表

#### Checklist

* [ ] 是否 **只记录事实**
* [ ] 是否 **不携带 duration**
* [ ] `firstLearn` 是否满足：

  * 仅在 **用户点击「加入复习」** 时写入
  * 每实体 **最多一次**
* [ ] 是否 **未被任何统计读取**

---

## 四、架构边界校验（Layer Rules）

* [ ] View 层：

  * [ ] 不做任何统计计算
  * [ ] 不直接访问 `daily_stats`
* [ ] Controller 层：

  * [ ] 只编排流程
  * [ ] 不推导统计语义
* [ ] Command 层：

  * [ ] 是 **唯一写入口**
* [ ] Query / Analytics：

  * [ ] **只读**
* [ ] Repository：

  * [ ] 仅 CRUD
  * [ ] 不含业务语义

---

## 五、反模式检查（必须全部为 ❌）

* [ ] ❌ 新增第二套统计表
* [ ] ❌ 在 UI / Controller 中计算 streak
* [ ] ❌ 从 logs 回放推导今日数据
* [ ] ❌ 在行为日志中恢复 `durationMs`
* [ ] ❌ 引入“补算 / 修正 / 回填”逻辑
* [ ] ❌ 为统计结果加缓存层
* [ ] ❌ 用“当前状态”解释“今日发生了什么”

---

## 六、代码落点确认（Spot Check）

* [ ] `PageDurationTracker`
  是否仍是 **唯一时间底座**
* [ ] `DailyStatCommand.applyTimeOnlyDelta`
  是否仍是 **唯一时间写入口**
* [ ] `firstLearn`
  是否只在「点击加入复习」路径出现
* [ ] `MasteredCountQuery`
  是否仍 **只读状态表**
* [ ] `DailyStatQuery.calculateStreak`
  是否仍未回退到 logs / 递归

---

## 七、封板规则（Hard Stop）

> **以下任一情况 → 必须立即停止讨论并回退改动**

* ❗ 需要“从 logs 重新算一次”
* ❗ 需要“补历史数据”
* ❗ 需要“兼容旧统计逻辑”
* ❗ 需要“临时算一下给 UI 用”
* ❗ 需要“解释为什么数字不一样”

---

## ✅ 通过标准（Merge Gate）

* 所有 Checklist 项 **100% 勾选**
* 没有新增统计路径
* 没有新增“解释性代码”
* `tech.md` 中的
  **《学习统计体系（封板）》无需更新**

---

### 🔒 最终声明（强制）

> **统计不一致不是展示问题，
> 而是实现错误。**
>
> **本 Checklist 对 Codex、未来功能、未来重构同等生效。**

---