---
inclusion: always
---

# 统计相关改动 Checklist（封板）

> **适用范围**
> 任何涉及以下内容的改动：
>
> * 学习统计
> * 今日学习 / 新学
> * 学习时长
> * streak（连续学习）
> * 掌握数
> * `daily_stats`
> * `study_logs / kana_logs`
>
> **⚠️ 以下检查项未全部通过 → 严禁合并代码**

---

## 一、数据来源校验（Source of Truth）

### ⏱ 学习时长（Time）

* [ ] 学习时长的 **唯一来源** 是否仍为 `PageDurationTracker`
* [ ] 是否 **只写入** `daily_stats.total_time_ms`
* [ ] 是否 **完全未使用** 以下来源计算或补算时间：

  * `study_logs`
  * `kana_logs`
  * Session / Accumulator
  * 行为参数 `durationMs`
* [ ] 页面驻留 < **最小阈值（2000ms）** 是否被静默丢弃
* [ ] 前后台切换是否正确：

  * `pause → flush`
  * `resume → restart`
* [ ] 是否不存在跨页面 / 跨日合并时间的隐式逻辑

---

### 📅 今日学习（New Learned / FirstLearn）

#### 语义确认（必须先确认）

> **今日学习 = 今日产生的 firstLearn 行为事件数量**

---

#### 数据来源检查

* [ ] 今日学习是否 **只来自**：

  ```text
  study_logs.log_type = firstLearn
  ```

* [ ] 是否 **不依赖** 以下任何内容：

  * `study_words.user_state`
  * `learning / mastered / seen`
  * `daily_stats` 以外的派生逻辑

---

#### 写入路径检查

* [ ] `firstLearn` 是否 **仅在用户点击「加入复习 / 开始学习」时写入**
* [ ] 是否保证 **每个 (user_id, word_id / kana_id) 仅一次 firstLearn**
* [ ] 是否在 **firstLearn 写入当下**：

  * 同步增量更新 `daily_stats.new_learned_count`
* [ ] 是否不存在：

  * 根据状态变化（seen → learning）补写 firstLearn
  * 根据 study_words 是否存在推导 firstLearn

---

#### 明确禁止

* [ ] ❌ 从 logs 回放计算“今日学习”
* [ ] ❌ 从状态表反推出“新学”
* [ ] ❌ 将 `learning / mastered` 当作新学

---

### 📖 今日复习（Review Count）

* [ ] UI 是否 **只读取** `daily_stats.review_count`
* [ ] 是否在 **复习行为发生时** 进行增量写入
* [ ] 是否不存在：

  * 从 logs 回放
  * 从 SRS 队列反推
  * 从状态表推导

---

## 二、累计类统计（State-based）

### 🧠 当前学习中（Learning）

* [ ] 是否只统计：

  ```text
  learning_status = learning
  ```

* [ ] 是否明确 **不等同于新学**

* [ ] 是否未被用于任何“今日”类统计

---

### 🏆 累计掌握（Mastered）

* [ ] 是否 **只读取状态表**：

  * `study_words.user_state = mastered`
  * `kana_learning_state.learning_status = mastered`
* [ ] 是否 **完全未使用**：

  * `daily_stats`
  * `study_logs / kana_logs`
* [ ] 是否为 **去重后的实体数**（不是行为次数）

---

### 🔥 连续学习（Streak）

* [ ] streak 是否 **只依赖** `daily_stats`
* [ ] 判定条件是否仍为：

  * 当天或昨天存在任意：

    * `new_learned_count > 0`
    * `review_count > 0`
    * `total_time_ms > 0`
* [ ] 是否使用 **gaps-and-islands**（非递归 CTE）
* [ ] 是否 **完全未从 logs 计算 streak**

---

## 三、写入路径校验（Write Path）

### daily_stats 写入规则

* [ ] 是否 **只通过** `DailyStatCommand`
* [ ] 是否满足以下硬规则：

  * `applyTimeOnlyDelta`

    * ✅ 只更新 `total_time_ms`
  * `applyLearningDelta`

    * ❌ 不更新 `total_time_ms`
* [ ] 是否不存在：

  * 页面直接写 DB
  * Repository 直接 update `daily_stats`
  * Query / Analytics 层写数据

---

### 行为日志（study_logs / kana_logs）

* [ ] 行为日志是否 **只记录用户行为事实**
* [ ] 是否 **不携带 duration**
* [ ] `firstLearn` 是否语义稳定：

  * 用户显式行为
  * 每实体仅一次
* [ ] 行为日志是否 **不被任何统计直接读取**

---

## 四、架构边界校验（Layer Rules）

* [ ] View 层：

  * [ ] 不做任何统计计算
  * [ ] 不直接访问 `daily_stats`
* [ ] Controller 层：

  * [ ] 只编排 Command / Query
  * [ ] 不计算统计
* [ ] Command 层：

  * [ ] 是所有写操作的唯一入口
* [ ] Query / Analytics：

  * [ ] 严格只读
* [ ] Repository：

  * [ ] 仅 CRUD
  * [ ] 无任何业务语义

---

## 五、反模式检查（必须全部为 ❌）

* [ ] ❌ 新增第二套统计表
* [ ] ❌ 在 UI / Controller 中计算 streak
* [ ] ❌ 从 logs 回放推导今日学习
* [ ] ❌ 从状态变化推导新学
* [ ] ❌ 在行为日志中恢复 `durationMs`
* [ ] ❌ 引入“补算 / 修正 / 回填”统计逻辑
* [ ] ❌ 为统计结果加缓存层

---

## 六、代码落点确认（Spot Check）

* [ ] `PageDurationTracker` 是否仍是 **唯一时间底座**
* [ ] `DailyStatCommand.applyTimeOnlyDelta` 是否仍是 **唯一时间写入口**
* [ ] `DailyStatCommand.applyLearningDelta` 是否仅由行为触发
* [ ] `MasteredCountQuery` 是否仍只读状态表
* [ ] `DailyStatQuery.calculateStreak` 是否未被改回 logs / 递归

---

## 七、封板规则（Hard Stop）

> **以下任一情况 → 必须立刻停下，回退改动**

* ❗ “我们从 logs 重新算一次吧”
* ❗ “历史数据需要补一下”
* ❗ “先兼容旧统计口径”
* ❗ “这个只是展示用，先算一下”

---

## ✅ 合并通过标准（必须全部满足）

* 所有勾选项 **100% 通过**
* 没有新增统计路径
* 没有新增“解释性统计代码”
* `tech.md` 中 **「学习统计体系（封板）」无需修改**
* `Learning Analytics Rules` 无需修改

---