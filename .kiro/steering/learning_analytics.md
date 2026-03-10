---
inclusion: always
---

# Learning Analytics Rules

> **Status: Frozen**
>
> 本文档定义 BreezeJP 中所有「学习统计 / 进度统计 / Dashboard 数值」的
> **唯一合法语义与口径**。
>
> **任何违反本文档的统计结果，均视为逻辑 Bug，
> 而非 UI 或展示问题。**

---

## 1. Scope（适用范围）

本规则适用于：

*   **单词（Word）学习**：完整遵循 Event-based + State-based 模型
*   **假名（Kana）学习**：遵循 State-based 模型，且复习行为已计入 `daily_stats.unique_kana_reviewed_count`
*   Dashboard / Home 页面统计
*   成就系统（若有）
*   周报 / 月报 / 学习总结（若有）

不适用于：

*   UI 展示样式
*   数据库存储结构
*   SRS 算法内部参数

---

## 2. 数据模型角色声明（关键）

在 BreezeJP 中，**学习统计必须严格区分三类数据角色**：

| 数据源        | 类型        | 角色           |
| ------------- | ----------- | -------------- |
| `study_words` | State-based | 当前状态       |
| `study_logs`  | Event-based | 用户行为事件   |
| `daily_stats` | Analytics   | 已确认统计结果 |

> ❗ 任何统计口径 **只能来自一个角色**
> ❌ 严禁 state 与 event 混用、互相推导

---

## 3. Learning Status Definitions（学习状态定义）

以下状态**仅用于描述当前状态，不直接参与统计计算**：

| Status     | Description                                |
| ---------- | ------------------------------------------ |
| `seen`     | 已曝光。内容被展示，但用户尚未做出学习承诺 |
| `learning` | 学习中。当前参与 SRS                       |
| `mastered` | 已掌握。学习生命周期完成                   |
| `ignored`  | 已忽略。用户明确选择不学习                 |

### 重要说明

* `seen` **不是学习行为**
* `learning` **不是学习事件**
* `mastered` **不是新学**
* `ignored` **不是学习成果**
* 状态变化 ≠ 用户行为

---

## 4. FirstLearn（首次学习事件）【核心修订】

### 定义（冻结）
- firstLearn 表示用户第一次点击「加入复习」
- 与 study_words 状态无关
- 每个 (user, word) 最多一次
- 是否计入“今日学习”，仅取决于 firstLearn.created_at 是否在今日
- mastered / ignored / restore 均不会产生 firstLearn

### 数据来源

```text
study_logs.log_type = firstLearn
```

### 严格规则

* 每个 `(user_id, content_id)` **最多只能有一条** firstLearn
* firstLearn **只由用户显式行为触发**
* firstLearn **与 learning_status 无关**

### 明确禁止

* ❌ 根据 `seen → learning` 推导 firstLearn
* ❌ 根据 `study_words` 是否存在来推导 firstLearn
* ❌ 因“方便”在状态更新时顺手写 firstLearn

---

## 5. 今日学习（New Learned Count）

### 定义（冻结）

> **今日学习 = 今日产生的 firstLearn 事件数量**

### 合法统计口径

```text
COUNT(study_logs)
WHERE log_type = firstLearn
  AND created_at = today

> 注：为了查询性能，该指标在 `firstLearn` 写入时会异步同步至 `daily_stats.new_learned_count`。
```

### 重要声明

* ❌ 不使用 `learning_status`
* ❌ 不使用 `study_words`
* ❌ 不回放 logs 重新计算
* ✅ firstLearn 写入时同步更新 `daily_stats.new_learned_count`

---

## 6. Learned Count（当前学习中数量）

### 定义

> **当前学习中内容数量（状态指标）**

### 统计口径

```text
learning_status = learning
```

### 说明

* 这是 **状态统计**
* 不等同于新学
* 不用于“今日学习”

---

## 7. Mastered Count（已掌握数量）

### 定义

> **已完成学习生命周期的内容数量**

### 统计口径

```text
learning_status = mastered
```

### 说明

* `mastered` 是学习生命周期的**终态**
* 不再参与 SRS
* 不代表“今日学习”

---

## 8. Ignored Count（忽略数量）【辅助指标】

### 定义

> 用户明确选择不学习的内容数量

### 统计口径

```text
learning_status = ignored
```

### 使用限制

* ❌ 不计入任何学习成果指标
* ❌ 不参与完成率 / 学习率计算
* ✅ 仅用于：

  * 推荐系统
  * 内容过滤
  * 用户行为分析

---

## 9. Completion Rate（完成率）

### 定义

> **完成率 = 已完成学习 / 曾进入学习的内容**

### 合法计算公式

```text
completion_rate = mastered / (learning + mastered)
```

### 明确禁止

* ❌ 将 `seen` 计入分母
* ❌ 将 `ignored` 计入分母
* ❌ 使用“内容总数”作为分母

---

## 10. SRS Participation Rules（SRS 参与规则）

| Status     | 是否进入 SRS |
| ---------- | ------------ |
| `seen`     | ❌            |
| `learning` | ✅            |
| `mastered` | ❌            |
| `ignored`  | ❌            |

> SRS **只对 learning 状态负责**
> 任何其它状态进入 SRS 都属于严重逻辑错误

---

## 11. Prohibitions（明确禁止事项）

以下行为**被明确禁止**：

* 将 `seen` 计入任何学习成果
* 将 `learning` 当作新学
* 将 `mastered` 当作新学
* 用状态变化替代用户行为
* 在 Query / Analytics 中重新解释统计口径
* 为“让数字好看”而调整定义

---

## 12. Change Policy（变更策略）

* 本文件为 **Freeze 文档**

* 任何修改必须同时更新：

  * 本文档
  * Analytics 实现
  * Dashboard 文案（如有）

* ❌ 禁止：

  * 私自改 SQL
  * 仅在 UI 层“修正解释”

---

## 13. Final Statement（最终冻结声明）

> **study_words 描述“现在是什么状态”
> study_logs 描述“用户做过什么”
> daily_stats 描述“已经确认的统计结果”**

> **任何混用三者语义的实现，
> 都是架构级错误，而不是实现细节问题。**

---

### 🔒 最后一条（强烈建议原样保留）

> **When analytics data feels wrong,
> check this document first.
> If analytics violates this document, it is a bug.**

---