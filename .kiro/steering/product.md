---
inclusion: always
---

# BreezeJP MVP 产品需求文档

## 产品概述

BreezeJP 是一款追求极致"心流"体验的日语单词记忆 App。采用全屏沉浸式交互（类似 TikTok）和关联语义探索（类似维基百科漫游），解决背单词枯燥和"孤岛记忆"的问题。

### 核心价值

- **沉浸感**：去 UI 化，全屏展示
- **清晰交互**：左右滑动切换单词，上下滑动查看详情，彻底解决手势冲突
- **关联性**：学完"狗"推荐"猫"，建立语义网络
- **掌控感**：通过分支选择避免难度失控，用户决定学习路径
- **自由度**：无每日新词上限，用户可无限探索
- **科学性**：底层支持 SM-2 与 FSRS 双算法引擎

## 应用架构

舍弃底部导航栏，采用单页 Dashboard 结构，所有功能入口汇聚于首页。

### 学习路径

1. 首页点击"开始学习"
2. **无尽探索阶段**:

   - 无缝进入语义分支模式
   - 学完一个词 → 选择下一个关联词 → 学完 → 选择...

3. 首页点击"待复习"
4. 进入极简复习模式，清理 SRS 队列

## 功能模块

# 首页（Dashboard）

首页是 BreezeJP 的学习控制中心。所有学习入口（单词学习、五十音学习、复习模式）均集中于首页，确保用户以最低认知成本开始学习。首页采用卡片式布局，可垂直滚动，内容分为六个区域：

1. Header
2. Primary Actions（三大主入口）
3. Stats Card（统计卡片）
4. Continue Learning（继续学习）
5. Recent Activity（最近学习记录）
6. Tools Grid（工具区）

---

## 1. Header（顶部区域）

展示内容：

- 问候语（根据时间段自动切换）
- 用户昵称
- 设置入口按钮

用途：增强用户归属感，并提供应用全局设置入口。

---

## 2. Primary Actions（三大主入口）

这是用户在首页最常用的操作区域，包含三个水平排列的入口按钮，用于启动不同学习模式：

- 回忆单词（Word Review）：进入单词复习模式，显示今日待复习数量。数据来自 study_words 表中 next_review_at <= now 的记录。
- 学习新单词（Learn New Words）：进入语义分支学习模式，无需数据查询，始终可用。
- 五十音复习（Kana Review）：进入五十音复习模式，显示今日待复习数量。数据来自 kana_learning_state 表中 next_review_at <= now 的记录。

设计说明：
三个入口是平级且独立的，用户可根据学习状态自由选择先复习还是先学习新内容。五十音复习作为单独学习模块，需要具备与单词复习同等重要度的入口。

---

## 3. Stats Card（学习统计卡片）

展示用户的关键学习指标，包括：

- 今日已学习单词数
- 今日已复习单词数
- 累计掌握词数
- 连续学习天数

数据来自 daily_stats 表。

用途：强化成就反馈，帮助用户持续坚持学习。

---

## 4. Continue Learning（继续学习卡片）

当用户之前正在进行某个学习 Session 时（例如语义分支学习模式中途退出），首页将显示“继续学习”卡片。

内容包括：

- 上次学习的单词或内容
- 当前 Session 的进度计数（例如“本次已学习 7 个词”）
- “继续学习”按钮，可快速回到学习流程

数据来源：

- study_words.user_state = 1（学习中）
- 或应用记忆的最近学习队列信息

用途：帮助用户迅速恢复学习心流，减少中断损耗。

---

## 5. Recent Activity（最近学习记录）

展示用户最近的学习行为，包括：

- 最近学习或复习过的单词
- 最近学习或练习的五十音
- 每条记录显示学习时间与行为类型（学习、复习、掌握等）

数据来源：

- study_logs 表（单词学习日志）
- kana_logs 表（五十音学习日志）

用途：建立学习轨迹回溯能力，让用户随时重新进入已学或近期练习内容。

---

## 6. Tools Grid（工具区）

展示低频工具入口，例如：

- 单词本
- 五十音图
- 详细统计
- 预留扩展功能入口

用途：集中存放功能性页面的入口，避免干扰主学习流程。

---

# 首页设计原则（更新版）

1. 主入口优先：Primary Actions 为首页最核心区域，用户进入 App 后立即可做出选择。
2. 复习与学习并列：复习入口不强制，但随时可用，允许用户自由选择先学新词或先清理复习任务。
3. 五十音独立模块：五十音复习为与单词复习等价的学习类型，应具备独立入口。
4. 信息密度适中：避免视觉和数据过载，突出关键功能。
5. 扩展性强：Tools Grid 可容纳未来更多功能，而不影响主入口区域。

---

### 学习流容器

技术实现：`PageView` (scrollDirection: Axis.horizontal) 全屏翻页

支持三种页面类型：

- **ReviewPage**：复习页（极简版，两阶段交互）
- **LearnPage**：学习页（完整展示，左右切换）
- **ChoicePage**：分支选择页（路由节点）

### 复习模式 (Review Mode)

场景：处理旧单词 (`user_state = 1`)，目标是无脑、快速

**阶段一：提问**

- 屏幕中央仅显示单词大字
- 下方灰色小字"点击查看释义"
- 点击屏幕任意区域进入阶段二

**阶段二：回答 暂时不需要**

- 展开显示假名、释义、例句
- 自动播放单词发音
- 底部 3 个评分按钮：
  - ❌ 忘了 → Rating 1 (Again)
  - ⭕ 记得 → Rating 3 (Good)
  - ⚡ 秒杀 → Rating 4 (Easy)
- 点击按钮 → 算法更新 → 自动滑入下一页

**防误触**：阶段一未看答案时，禁止手动滑到下一页

### 语义分支学习模式 (Associative Learn Mode)

场景：学习新单词，无尽探索模式

#### 启动流程

**初始选择页 (Initial Choice Page)**

- 从 `words` 表随机选取 5 个单词作为起点
- 筛选条件：
  ```sql
  SELECT w.* FROM words w
  LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = [CurrentUserID]
  WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
  ORDER BY RANDOM()
  LIMIT 5;
  ```
- 展示 5 个选项卡片，显示单词、假名、难度标签
- 用户点击其中一个 → 进入该单词的学习页 → 同时加载该单词的所有关联词

#### 学习流程

**单词学习页 (LearnPage)**

- 全屏展示单词、假名、释义、例句
- 左右滑动切换单词（在当前关联词队列中切换）
- 页面展示时：
  - 标记为"学习中"（`user_state = 1`）
  - 写入 `study_logs` (log_type = 1)
  - 更新 `study_words` 表

#### 关联词加载逻辑

**获取关联单词（所有关联词）**

```sql
SELECT w.*, wr.score, wr.relation_type
FROM word_relations wr
JOIN words w ON wr.related_word_id = w.id
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = [CurrentUserID]
WHERE wr.word_id = [CurrentWordID]
  AND (sw.user_state IS NULL OR sw.user_state IN (0, 1))
ORDER BY wr.score DESC;
```

**加载时机**：

1. 用户在初始选择页选择单词时 → 加载该单词的所有关联词
2. 用户学完当前队列的最后一个单词时 → 自动基于最后一个单词加载新的关联词
3. 如果某个单词没有找到关联词 → 回到初始选择页，随机展示 5 个新单词

**队列管理**：

- 当前学习队列包含该单词的所有关联词（数量不固定）
- 学完最后一个单词后，自动追加该单词的所有关联词到队列
- 形成无限链条：词 A → [所有关联词] → 基于最后一个词 → [新的所有关联词] → ...

#### 无尽循环机制

**正常流程**：

- 学习词 1 → 学习词 2 → ... → 学习词 N（最后一个关联词） → 自动加载词 N 的关联词 → 继续学习 → ...

**断链处理**：

- 如果最后一个单词没有关联词 → 显示"已探索完这条路径" → 返回初始选择页
- 用户重新选择 5 个随机单词中的一个 → 继续探索

**已学词过滤**：

- 已掌握的词（`user_state = 2`）不会出现在关联词列表中
- 确保用户始终学习新词或复习中的词

#### 退出机制

- 点击左上角"关闭"按钮或右滑返回
- 结算本次 Session：
  - 统计学习时长
  - 统计学习单词数
  - 更新 `daily_stats` 表

## 算法逻辑

### 推荐算法

**关联词推荐（所有关联词）**：

```sql
SELECT w.*, wr.score, wr.relation_type
FROM word_relations wr
JOIN words w ON wr.related_word_id = w.id
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = [CurrentUserID]
WHERE wr.word_id = [CurrentWordID]
  AND (sw.user_state IS NULL OR sw.user_state IN (0, 1))
ORDER BY wr.score DESC;
```

**随机起点推荐（5 个）**：

```sql
SELECT w.* FROM words w
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = [CurrentUserID]
WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
ORDER BY RANDOM()
LIMIT 5;
```

UI 层根据 `jlpt_level` 渲染难度标签（N5=绿, N1=红）

### 记忆算法

- 默认使用 SM-2
- 预留 FSRS 接口，Pro 设置开启后读写 `stability` 和 `difficulty` 字段

## UI/UX 规范

- **手势**：学习模式左右滑动切换单词
- **震动反馈**：页面切换时触发 `HapticFeedback.lightImpact()`
- **进度反馈**：右上角显示本次 Session 计数器（本次已学 +5）
- **国际化**：所有用户可见文本必须使用 `AppLocalizations`，禁止硬编码字符串

## MVP 范围外

暂不开发：

- 用户注册/登录/云同步（使用本地 SQLite）
- 自定义生词本/词单创建
- 听写模式/拼写模式
- 社交功能
- 每日新词上限设置
