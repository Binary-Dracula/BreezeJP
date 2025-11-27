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

1. 首页点击"待复习"
2. 进入极简复习模式，清理 SRS 队列

## 功能模块

### 首页 (Dashboard)

布局：Bento Grid 网格仪表盘，垂直滚动

| 组件 | 功能 | 数据逻辑 |
|------|------|----------|
| Header | 问候语、用户名、设置入口 | 读取本地配置 |
| Review Card | 显示待复习数量，"清理今日记忆债务"<br>点击进入复习模式 | 查询 `study_words` 表中 `next_review_at <= now` 的数量 |
| Explore Card | 显示"开始探索"，"发现新的日语世界"<br>点击进入语义分支学习模式 | 无需数据查询，始终可用 |
| Stats Row | 连续打卡天数、已掌握词数、今日已学数 | 读取 `daily_stats` 表 |
| Tools Grid | 2x2 网格：单词本、详细统计、(预留位) | 路由跳转 |

**设计说明**：
- Review Card 和 Explore Card 是两个独立的入口卡片，互不干扰
- 即使有待复习单词，用户仍可选择进入探索模式学习新词
- 即使没有待复习单词，Review Card 仍然显示（显示 0 个待复习）
- 两种模式可以自由切换，用户完全掌控学习节奏

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
- 形成无限链条：词A → [所有关联词] → 基于最后一个词 → [新的所有关联词] → ...

#### 无尽循环机制

**正常流程**：
- 学习词1 → 学习词2 → ... → 学习词N（最后一个关联词） → 自动加载词N的关联词 → 继续学习 → ...

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

## MVP 范围外

暂不开发：
- 用户注册/登录/云同步（使用本地 SQLite）
- 自定义生词本/词单创建
- 听写模式/拼写模式
- 社交功能
- 每日新词上限设置
