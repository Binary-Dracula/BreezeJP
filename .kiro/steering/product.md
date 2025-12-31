---
inclusion: always
---

# BreezeJP MVP 产品需求文档

## 一、产品概述

BreezeJP 是一款追求极致「心流」体验的日语学习 App，核心聚焦 **单词（Word）与五十音（Kana）** 两类基础学习对象。

产品通过：

* 全屏沉浸式交互（类似 TikTok）
* 自由探索式学习路径（类似维基百科漫游）
* 明确、可控的学习行为分支

解决传统背单词应用中常见的：

* 枯燥
* 强任务感
* 学习路径失控
* 统计口径混乱

---

## 二、核心价值

* **沉浸感**：去 UI 化，全屏展示内容，减少干扰
* **清晰交互**：左右滑动切换内容，上下查看详情，杜绝手势冲突
* **关联性**：通过语义关系引导自然扩展学习
* **掌控感**：所有学习推进均由用户显式操作决定
* **自由度**：无每日新词上限、无强制复习顺序
* **科学性**：底层支持 SM-2 与 FSRS 双算法

---

## 三、应用架构总览

* 无底部导航栏
* 单页 Dashboard 作为学习控制中心
* 所有学习入口、复习入口、统计入口统一汇聚在首页

---

## 四、首页（Dashboard）

首页是 BreezeJP 的**学习调度中心**，而非任务列表。

### 模块组成

1. Header（顶部区域）
2. Primary Actions（学习主入口）
3. Review Section（复习模块）
4. Stats Card（学习统计）
5. Tools Grid（工具区）

### 用户分层原则

* **新用户**：尚未产生任何学习事件
* **已有学习用户**：存在任意 `study_words / kana_learning_state` 记录

所有模块根据用户状态 **显示内容不同，但结构不变**。

---

## 五、Header（顶部区域）

展示内容：

* 时间段问候语
* 用户昵称（来自 `users`）
* 设置入口

**Header 不依赖任何学习 / 统计数据**，不做条件渲染。

---

## 六、Primary Actions（学习主入口）

始终可见，永不禁用。

### 1️⃣ 学习新单词（Learn New Words）

功能特征：

* 进入语义关联学习流
* 无章节 / 无进度条 / 无任务提示
* 页面切换仅表示“浏览内容”，不等同学习

**重要约束（冻结）：**

* 单词在被展示时，只会进入 `seen`
* 不会自动进入 `learning`
* 不会自动产生学习统计

---

### 2️⃣ 学习五十音（Learn Kana）

功能特征：

* 任意假名可自由进入
* 不显示“已学 X 个”的进度提示
* 固定集合，不做完成度引导

---

## 七、Review Section（复习模块）

复习是 BreezeJP 唯一的 **强学习入口**。

### 复习单词（Review Words）

数据来源：

```text
study_words
WHERE
  user_id = current
  AND learning_status = learning
  AND next_review_at <= now
```

* 入口始终可点击
* 数量为 0 时展示引导文案

---

### 复习五十音（Review Kana）

数据来源：

```text
kana_learning_state
WHERE
  user_id = current
  AND learning_status = learning
  AND next_review_at <= now
```

---

### 复习模块原则（冻结）

* 复习不压制学习
* 单词 / 假名 SRS 队列完全独立
* Dashboard **只负责展示数量，不干预行为**

---

## 八、Stats Card（学习统计）

Stats Card 仅用于**展示结果**，不承担解释职责。

### 展示指标

* 今日学习（新学）
* 今日复习
* 累计掌握
* 连续学习天数
* 今日学习时长

### 数据来源（冻结）

* **全部来自 `daily_stats`**
* UI 不做任何派生计算

---

## 九、Word 学习生命周期（冻结）

### 1️⃣ 状态定义

| 状态         | 含义                |
| ---------- | ----------------- |
| `seen`     | 单词被展示过，但用户尚未承诺学习  |
| `learning` | 用户点击「加入复习」，进入 SRS |
| `mastered` | 用户完成学习，不再复习       |
| `ignored`  | 用户明确选择不学习         |

---

### 2️⃣ `seen` 的唯一创建时机（冻结）

`seen` **只允许**在以下时机创建：

* 用户在 Learn 页面中
* 左右滑动 **第一次看到该单词**
* 触发点：`LearnController.onPageChanged`

**明确禁止：**

* 页面初始化
* 音频播放
* 停留时间判断
* 任意按钮点击

---

### 3️⃣ `learning` 的唯一进入方式（冻结）

`learning` **只能由用户显式行为触发**：

* 点击「加入复习」
* 点击「一键掌握」（状态由`seen → mastered`,不经过`learning` ）

禁止任何自动、隐式进入。

---

### 4️⃣ `mastered` 规则（冻结）

* UI 可直接提供“一键掌握”
* 数据层必须完整保留中间状态
* 状态由 `seen → mastered`

---

### 5️⃣ `ignored` 规则（冻结）

* 任意状态可进入
* 不进入 SRS
* 不计入任何学习成果
* 可恢复为 `seen`

---

### 6️⃣ 操作栏（UI 冻结）

| 状态         | 可见操作             |
| ---------- | ---------------- |
| `seen`     | 加入复习 / 一键掌握 / 忽略 |
| `learning` | 已掌握 / 忽略         |
| `ignored`  | 恢复学习             |
| `mastered` | 恢复学习               |

---

### 7️⃣ 与 Kana 的同构声明（冻结）

* 状态枚举完全一致
* 行为语义完全一致
* Command / Query / Controller 结构完全对齐
* 不允许 Word 单独引入特殊规则

---

## 十、统计语义补充说明（冻结）

firstLearn 定义（冻结）：
- firstLearn 表示用户第一次点击「加入复习」
- 与 study_words 状态无关
- 每个 (user, word) 最多一次
- 是否计入“今日学习”，仅取决于 firstLearn.created_at 是否在今日
- mastered / ignored / restore 均不会产生 firstLearn


---

## 十一、记忆算法

* 默认：SM-2
* 可切换：FSRS
* 使用字段：`interval / ease_factor / stability / difficulty`

---

## 十二、UI / UX 规范

* 左右滑动切换内容
* 页面切换触发轻量震动
* Session 内计数仅用于即时反馈
* 所有文案必须使用 `AppLocalizations`

---

## 十三、最终冻结声明（强约束）

> **本 PRD 不只是产品说明，
> 而是 BreezeJP MVP 的行为契约。**
>
> 任意实现：
>
> * 若与本文档冲突 → 视为 Bug
> * 若需调整 → 必须先修改本文档

**本文件自 MVP 起冻结。**