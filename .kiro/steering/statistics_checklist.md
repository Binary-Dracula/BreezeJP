# 统计相关改动 Checklist（封板）

> **适用范围**：
> 任何涉及 **学习统计 / 时长 / streak / 掌握数 / daily_stats / logs** 的改动
> **未全部勾选通过 → 不允许合并**

---

## 一、数据来源校验（Source of Truth）

### ⏱ 学习时长（time）

* [ ] **唯一来源** 是否仍为 `PageDurationTracker`
* [ ] 是否 **只写入** `daily_stats.total_time_ms`
* [ ] 是否 **没有** 从以下来源计算时间：

  * `study_logs`
  * `kana_logs`
  * session / accumulator
  * 行为参数 `durationMs`
* [ ] 页面驻留 < 最小阈值（2000ms）是否被静默丢弃
* [ ] 前后台切换是否正确 flush / resume

---

### 📅 今日学习 / 今日复习

* [ ] UI 是否 **只读取** `daily_stats`

  * `new_learned_count`
  * `review_count`
* [ ] 是否 **没有**：

  * 从 logs 回放计算“今日”
  * 从库存表（study_words / kana_learning_state）反推“今日”
* [ ] 写入是否发生在 **行为发生时的增量更新**
* [ ] 是否不存在“跨天补算 / 重算”逻辑

---

### 🧠 累计掌握（Mastered）

* [ ] 是否 **只读取** 状态表：

  * `study_words.user_state = mastered`
  * `kana_learning_state.learning_status = mastered`
* [ ] 是否 **完全未使用**：

  * `daily_stats`
  * `study_logs`
  * `kana_logs`
* [ ] 是否为 **去重后的实体数**（而非次数）

---

### 🔥 连续学习（Streak）

* [ ] 是否 **只依赖** `daily_stats`
* [ ] 判定条件是否仍为：

  * 当天或昨天存在任意：

    * `new_learned_count > 0`
    * `review_count > 0`
    * `total_time_ms > 0`
* [ ] 是否使用 **gaps-and-islands**（非递归 CTE）
* [ ] 是否完全未从 logs 计算 streak

---

## 二、写入路径校验（Write Path）

### daily_stats 写入

* [ ] 是否 **只通过** `DailyStatCommand`
* [ ] 是否满足：

  * `applyTimeOnlyDelta`

    * **仅** 更新 `total_time_ms`
  * `applyLearningDelta`

    * **不更新** `total_time_ms`
* [ ] 是否不存在：

  * 页面直接写 DB
  * Repository 直接 update daily_stats
  * Analytics / Query 层写数据

---

### 行为日志（study_logs / kana_logs）

* [ ] 是否 **仍然只记录事实**
* [ ] 是否 **不携带 duration**
* [ ] `firstLearn` 是否语义稳定（每实体仅一次）
* [ ] 是否未被用于任何统计读取

---

## 三、架构边界校验（Layer Rules）

* [ ] View 层：

  * [ ] 不做任何统计计算
  * [ ] 不直接访问 daily_stats
* [ ] Controller 层：

  * [ ] 只编排，不计算
* [ ] Command 层：

  * [ ] 是唯一写入口
* [ ] Query / Analytics：

  * [ ] **只读**
* [ ] Repository：

  * [ ] 仅 CRUD，无语义

---

## 四、反模式检查（必须全部为 ❌）

* [ ] ❌ 新增第二套统计表
* [ ] ❌ 在 UI / Controller 中计算 streak
* [ ] ❌ 从 logs 回放推导今日数据
* [ ] ❌ 在行为日志中恢复 durationMs
* [ ] ❌ 引入“补算 / 修正 / 回填”统计逻辑
* [ ] ❌ 为统计加缓存层

---

## 五、代码落点确认（Spot Check）

* [ ] `PageDurationTracker` 是否仍是 **唯一时间底座**
* [ ] `DailyStatCommand.applyTimeOnlyDelta` 是否仍是 **唯一时间写入口**
* [ ] `MasteredCountQuery` 是否仍只读状态表
* [ ] `DailyStatQuery.calculateStreak` 是否未被改回递归 / logs

---

## 六、封板规则（Hard Stop）

> **以下任一情况 → 必须停下讨论，回退改动**

* ❗ 需要“从 logs 重新算一次”
* ❗ 需要“补历史数据”
* ❗ 需要“兼容旧统计逻辑”
* ❗ 需要“临时算一下展示用”

---

## ✅ 通过标准

* 所有勾选项 **100% 满足**
* 没有新增统计路径
* 没有新增“解释性代码”
* tech.md 中的「学习统计体系（封板）」无需更新
