---
inclusion: always
---

# 数据库架构

BreezeJP 使用 SQLite 本地数据库（`assets/database/breeze_jp.sqlite`），包含 5 个核心表。

## 表结构总览

### 词汇数据表
1. `words` - 单词核心信息
2. `word_meanings` - 单词释义（一对多）
3. `word_audio` - 单词音频文件（一对多）
4. `example_sentences` - 例句（一对多）
5. `example_audio` - 例句音频文件（一对多）

### 学习进度表
6. `study_words` - 用户学习进度和 SRS 数据
7. `study_logs` - 学习日志和历史记录
8. `daily_stats` - 每日学习统计汇总

## 表详细定义

### words
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键，唯一标识单词 |
| word | TEXT NOT NULL | 单词文本（汉字/假名混合） |
| furigana | TEXT | 单词假名（Furigana） |
| romaji | TEXT | 单词罗马音 |
| jlpt_level | TEXT | 单词对应 JLPT 等级，如 N5、N4 |
| part_of_speech | TEXT | 词性，如名词、动词 |
| pitch_accent | TEXT | 音调标记 |

### word_meanings
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| word_id | INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE | 对应单词 |
| meaning_cn | TEXT NOT NULL | 中文释义 |
| definition_order | INTEGER DEFAULT 1 | 释义顺序 |
| notes | TEXT | 可选注释或例句来源 |

### word_audio
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| word_id | INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE | 对应单词 |
| audio_filename | TEXT NOT NULL | 文件名，例如 `高校_koukou_default_default.mp3` |
| audio_url | TEXT | 音频文件的 URL 地址（可选，用于在线音频） |
| voice_type | TEXT | 音频类型，如 default / NHK / other |
| source | TEXT | 来源，如 default / NHK / TTS |

**音频文件路径**：
- 本地文件：`assets/audio/words/[audio_filename]`
- 在线文件：使用 `audio_url` 字段存储的 URL

### example_sentences
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| word_id | INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE | 对应单词 |
| sentence_jp | TEXT NOT NULL | 日文例句，可能含 `<b>` 高亮学习单词 |
| sentence_furigana | TEXT | 例句假名注音 |
| translation_cn | TEXT | 中文翻译 |
| notes | TEXT | 可选注释或来源 |

**注意**：`sentence_jp` 中使用 `<b>` 标签高亮目标单词

### example_audio
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| example_id | INTEGER NOT NULL REFERENCES example_sentences(id) ON DELETE CASCADE | 对应例句 |
| audio_filename | TEXT NOT NULL UNIQUE | 文件名，例如 `sentence_1_default_default.mp3` |
| audio_url | TEXT | 音频文件的 URL 地址（可选，用于在线音频） |
| voice_type | TEXT DEFAULT 'default' | 音频类型 |
| source | TEXT DEFAULT 'default' | 来源 |

**音频文件路径**：
- 本地文件：`assets/audio/examples/[audio_filename]`
- 在线文件：使用 `audio_url` 字段存储的 URL

### study_words
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| user_id | INTEGER NOT NULL | 用户 ID |
| word_id | INTEGER NOT NULL | 对应单词 ID |
| user_state | INTEGER NOT NULL DEFAULT 0 | 用户对单词的状态（见下方说明） |
| next_review_at | INTEGER | 下次复习时间（Unix 时间戳） |
| last_reviewed_at | INTEGER | 上次复习时间（Unix 时间戳） |
| interval | REAL DEFAULT 0 | 当前复习间隔（天） |
| ease_factor | REAL DEFAULT 2.5 | 难度因子 EF（越低越难） |
| streak | INTEGER DEFAULT 0 | 连续答对次数 |
| total_reviews | INTEGER DEFAULT 0 | 累计复习次数 |
| fail_count | INTEGER DEFAULT 0 | 答错次数（不认识） |
| created_at | INTEGER NOT NULL DEFAULT (strftime('%s','now')) | 创建时间 |
| updated_at | INTEGER NOT NULL DEFAULT (strftime('%s','now')) | 更新时间 |
| UNIQUE(user_id, word_id) | | 唯一约束：每个用户每个单词只有一条记录 |

**user_state 状态说明**：
- `0` - 未学习（新单词）
- `1` - 学习中（SRS 正常进行）
- `2` - 已掌握（用户主动标记"我已经会了，不需要学习"）
- `3` - 忽略（例如脏词、用户不想学）

**SRS 参数说明**：
- `interval`: 当前复习间隔（天），随着答对次数增加而增长
- `ease_factor`: 难度因子（默认 2.5），影响间隔增长速度
- `streak`: 连续答对次数，用于判断是否掌握
- `fail_count`: 累计答错次数，用于统计学习难度

### study_logs
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| user_id | INTEGER NOT NULL | 用户 ID |
| word_id | INTEGER NOT NULL | 单词 ID |
| log_type | INTEGER NOT NULL | 事件类型（见下方说明） |
| rating | INTEGER | 复习评分（1-4，仅用于复习事件） |
| interval_after | REAL | 操作后的间隔（天） |
| ease_factor_after | REAL | 操作后的难度因子 |
| next_review_at_after | INTEGER | 操作后的下次复习时间戳 |
| duration_ms | INTEGER DEFAULT 0 | 学习/复习花费时间（毫秒） |
| created_at | INTEGER NOT NULL DEFAULT (strftime('%s','now')) | 创建时间 |

**log_type 事件类型说明**：
- `1` - 初次学习（第一次学习该单词）
- `2` - 复习（SRS 复习）
- `3` - 手动标记已掌握
- `4` - 手动忽略
- `5` - 手动恢复/重置（从已掌握回到学习中）
- `6` - 自动计划生成今日任务（可选）

**rating 复习评分说明**（仅用于 log_type = 2）：
- `1` - Again（完全忘记）
- `2` - Hard（困难，勉强记起）
- `3` - Good（一般，正常记起）
- `4` - Easy（简单，轻松记起）

**用途**：
- 记录用户的学习历史和行为轨迹
- 分析学习效果和习惯
- 生成学习报告和统计图表
- 追踪 SRS 算法的调整过程

### daily_stats
| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER PK AUTOINCREMENT | 主键 |
| user_id | INTEGER NOT NULL | 用户 ID |
| date | TEXT NOT NULL | 日期（YYYY-MM-DD 格式） |
| total_study_time | INTEGER DEFAULT 0 | 当天学习总时长（秒） |
| learned_words_count | INTEGER DEFAULT 0 | 当天新学单词数量 |
| reviewed_words_count | INTEGER DEFAULT 0 | 当天复习单词数量 |
| mastered_words_count | INTEGER DEFAULT 0 | 当天手动标记掌握数量 |
| failed_count | INTEGER DEFAULT 0 | 当天错误次数（忘记次数） |
| created_at | INTEGER NOT NULL DEFAULT (strftime('%s','now')) | 创建时间 |
| updated_at | INTEGER NOT NULL DEFAULT (strftime('%s','now')) | 更新时间 |
| UNIQUE(user_id, date) | | 唯一约束：每个用户每天只有一条记录 |

**用途**：
- 快速查询每日学习数据，无需实时聚合 study_logs
- 生成学习报表和趋势图
- 展示学习日历和热力图
- 计算学习连续天数（streak）

**更新时机**：
- 每次学习/复习后实时更新当天记录
- 或使用定时任务每天凌晨汇总前一天数据

## 数据关系

### 词汇数据关系
```
words (1) ──< (N) word_meanings
      (1) ──< (N) word_audio
      (1) ──< (N) example_sentences (1) ──< (N) example_audio
```

### 学习进度关系
```
words (1) ──< (N) study_words (N) ──> (1) user
      (1) ──< (N) study_logs (N) ──> (1) user
                                (1) ──< (N) daily_stats
```

**关系说明**：
- 词汇数据表的外键使用 `ON DELETE CASCADE`，删除单词时自动清理关联数据
- `words` 是核心表，其他表通过 `word_id` 或 `example_id` 关联
- `study_words` 记录用户对每个单词的当前学习状态，通过 `(user_id, word_id)` 唯一约束确保每个用户每个单词只有一条记录
- `study_logs` 记录所有学习事件的历史日志，用于分析和统计
- `daily_stats` 汇总每日学习数据，通过 `(user_id, date)` 唯一约束确保每个用户每天只有一条记录

## 常见查询模式

### 词汇查询

#### 查询单词及其释义
```sql
SELECT w.*, wm.meaning_cn 
FROM words w
LEFT JOIN word_meanings wm ON w.id = wm.word_id
WHERE w.jlpt_level = 'N5'
ORDER BY wm.definition_order;
```

#### 查询单词的例句和音频
```sql
SELECT es.*, ea.audio_filename
FROM example_sentences es
LEFT JOIN example_audio ea ON es.id = ea.example_id
WHERE es.word_id = ?;
```

#### 获取单词音频
```sql
SELECT audio_filename, audio_url FROM word_audio WHERE word_id = ? LIMIT 1;
```

### 学习进度查询

#### 获取用户的学习进度
```sql
SELECT sw.*, w.word, w.furigana
FROM study_words sw
JOIN words w ON sw.word_id = w.id
WHERE sw.user_id = ?
ORDER BY sw.updated_at DESC;
```

#### 获取需要复习的单词
```sql
SELECT sw.*, w.*
FROM study_words sw
JOIN words w ON sw.word_id = w.id
WHERE sw.user_id = ?
  AND sw.user_state = 1  -- 学习中
  AND sw.next_review_at <= strftime('%s', 'now')  -- 到期
ORDER BY sw.next_review_at ASC;
```

#### 获取用户的学习统计
```sql
SELECT 
  COUNT(*) as total_words,
  SUM(CASE WHEN user_state = 0 THEN 1 ELSE 0 END) as new_words,
  SUM(CASE WHEN user_state = 1 THEN 1 ELSE 0 END) as learning_words,
  SUM(CASE WHEN user_state = 2 THEN 1 ELSE 0 END) as mastered_words,
  SUM(total_reviews) as total_reviews,
  AVG(ease_factor) as avg_ease_factor
FROM study_words
WHERE user_id = ?;
```

#### 获取某个 JLPT 等级的学习进度
```sql
SELECT w.jlpt_level, 
       COUNT(*) as total,
       SUM(CASE WHEN sw.user_state = 2 THEN 1 ELSE 0 END) as mastered
FROM words w
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
WHERE w.jlpt_level = 'N5'
GROUP BY w.jlpt_level;
```

### 学习日志查询

#### 获取用户的学习历史
```sql
SELECT sl.*, w.word, w.furigana
FROM study_logs sl
JOIN words w ON sl.word_id = w.id
WHERE sl.user_id = ?
ORDER BY sl.created_at DESC
LIMIT 50;
```

#### 获取某个单词的学习历史
```sql
SELECT *
FROM study_logs
WHERE user_id = ? AND word_id = ?
ORDER BY created_at ASC;
```

#### 统计每日学习数量
```sql
SELECT 
  DATE(created_at, 'unixepoch', 'localtime') as date,
  COUNT(*) as total_reviews,
  SUM(CASE WHEN log_type = 1 THEN 1 ELSE 0 END) as new_learned,
  SUM(CASE WHEN log_type = 2 THEN 1 ELSE 0 END) as reviews,
  AVG(duration_ms) as avg_duration
FROM study_logs
WHERE user_id = ?
  AND created_at >= strftime('%s', 'now', '-30 days')
GROUP BY date
ORDER BY date DESC;
```

#### 分析复习评分分布
```sql
SELECT 
  rating,
  COUNT(*) as count,
  AVG(duration_ms) as avg_duration
FROM study_logs
WHERE user_id = ? AND log_type = 2
GROUP BY rating
ORDER BY rating;
```

#### 获取学习时长统计
```sql
SELECT 
  SUM(duration_ms) / 1000.0 / 60.0 as total_minutes,
  COUNT(*) as total_sessions,
  AVG(duration_ms) / 1000.0 as avg_seconds
FROM study_logs
WHERE user_id = ?
  AND created_at >= strftime('%s', 'now', '-7 days');
```

### 每日统计查询

#### 获取用户的每日统计
```sql
SELECT *
FROM daily_stats
WHERE user_id = ?
ORDER BY date DESC
LIMIT 30;
```

#### 获取指定日期范围的统计
```sql
SELECT *
FROM daily_stats
WHERE user_id = ?
  AND date >= '2024-01-01'
  AND date <= '2024-01-31'
ORDER BY date ASC;
```

#### 计算学习连续天数
```sql
WITH RECURSIVE dates AS (
  SELECT date, 
         ROW_NUMBER() OVER (ORDER BY date DESC) as rn
  FROM daily_stats
  WHERE user_id = ?
    AND total_study_time > 0
  ORDER BY date DESC
),
groups AS (
  SELECT date,
         DATE(date, '-' || (rn - 1) || ' days') as group_date
  FROM dates
)
SELECT COUNT(*) as streak
FROM groups
WHERE group_date = (SELECT MAX(date) FROM daily_stats WHERE user_id = ?)
GROUP BY group_date
ORDER BY streak DESC
LIMIT 1;
```

#### 获取本周/本月统计汇总
```sql
-- 本周
SELECT 
  SUM(total_study_time) as total_time,
  SUM(learned_words_count) as total_learned,
  SUM(reviewed_words_count) as total_reviewed,
  AVG(total_study_time) as avg_time_per_day
FROM daily_stats
WHERE user_id = ?
  AND date >= DATE('now', 'weekday 0', '-7 days')
  AND date <= DATE('now');

-- 本月
SELECT 
  SUM(total_study_time) as total_time,
  SUM(learned_words_count) as total_learned,
  SUM(reviewed_words_count) as total_reviewed,
  COUNT(*) as active_days
FROM daily_stats
WHERE user_id = ?
  AND date >= DATE('now', 'start of month')
  AND date <= DATE('now');
```

## 数据模型映射规则

创建 Dart 模型时：
- 表名 → 类名（PascalCase）：`words` → `Word`
- 列名 → 属性名（camelCase）：`word_id` → `wordId`
- 外键关系 → 可选的关联对象或 ID 属性
- 实现 `fromMap(Map<String, dynamic> map)` 和 `toMap()`

## 音频文件命名规范

- 单词音频：`[单词]_[romaji]_[voice_type]_[source].mp3`
- 例句音频：`sentence_[example_id]_[voice_type]_[source].mp3`