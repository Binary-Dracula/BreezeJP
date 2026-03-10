---
inclusion: always
---

# 数据库模式参考

## 概览

**数据库**：位于 `assets/database/breeze_jp.sqlite` 的本地 SQLite  
**访问方式**：Repository 内部使用 `AppDatabase.instance`，Query / Analytics 通过 `databaseProvider` 注入 Database（Controller / Debug 不直接访问）  
**23 张核心表**：

- **单词基础**：words、word_meanings、word_audio、example_sentences、example_audio、word_relations、conjugation_types、word_conjugations
- **语法基础**：grammars、grammar_meanings、grammar_contexts、grammar_examples
- **学习进度**：study_words、study_grammars、study_logs、daily_stats、kana_learning_state
- **账号及状态**：users、app_state
- **假名基础**：kana_letters、kana_audio、kana_examples、kana_stroke_order

## AI 助手必须遵守的规则

1. **Controller / View / Debug 不得直接访问数据库**，只能通过 Command / Query / Analytics。
2. **Repository 仅限单表 CRUD**，不得包含 join / 统计 / 业务语义。
3. **Repository 内部可使用 `AppDatabase.instance`**，但不得向外暴露 Database。
4. **Query / Analytics 只读**，通过 `databaseProvider` 注入 Database。
5. **Command 是唯一写入口**，不返回 Map 或 SQL 原始结果。
6. **所有模型类必须实现**：`fromMap(Map<String, dynamic>)` 构造和 `toMap()` 方法。
7. **命名规则**：数据库使用 snake_case，Dart 使用 camelCase。
8. **时间字段**：所有 `*_at` 为 Unix 秒级时间戳，读取时用 `DateTime.fromMillisecondsSinceEpoch(value * 1000)`。
9. **用户上下文**：当前用户来自 `app_state.current_user_id`，由 ActiveUserCommand / ActiveUserQuery 负责读写。

## 表结构速查

| 表名                | 主键 | 作用                 | 关键索引                                                            |
| ------------------- | ---- | -------------------- | ------------------------------------------------------------------- |
| words               | id   | 单词词典             | -                                                                   |
| word_meanings       | id   | 单词释义（1:N）      | idx_meanings_word_id                                                |
| word_audio          | id   | 单词发音文件（1:N）  | -                                                                   |
| example_sentences   | id   | 例句（1:N）          | idx_examples_word_id                                                |
| example_audio       | id   | 例句音频（1:N）      | -                                                                   |
| word_relations      | id   | 语义关联词           | idx_word_relations_word_id，idx_word_relations_related_word_id      |
| grammars            | id   | 语法条目             | -                                                                   |
| grammar_meanings    | id   | 语法义项（1:N）      | idx_grammar_meanings_grammar_id                                     |
| grammar_contexts    | id   | 语法场景限制（1:N）  | -                                                                   |
| grammar_examples    | id   | 语法例句（1:N）      | idx_grammar_examples_grammar_id                                     |
| study_words         | id   | 每个单词的学习进度   | idx_study_schedule (user_id, user_state, next_review_at)            |
| study_logs          | id   | 学习日志             | idx_logs_word (user_id, word_id, created_at)                        |
| daily_stats         | id   | 每日汇总统计         | UNIQUE(user_id, date)                                               |
| users               | id   | 用户表               | UNIQUE(username), UNIQUE(email)                                     |
| app_state           | id=1 | 当前活跃用户（单例） | -                                                                   |
| kana_letters        | id   | 假名母表             | -                                                                   |
| kana_audio          | id   | 假名发音文件         | -                                                                   |
| kana_examples       | id   | 假名示例词           | -                                                                   |
| kana_learning_state | id   | 假名学习进度         | idx_kana_review_schedule (user_id, learning_status, next_review_at) |
| kana_stroke_order   | id   | 假名笔顺 SVG         | -                                                                   |

---

## 详细表定义

### words

| 字段           | 类型    | 说明                          |
| -------------- | ------- | ----------------------------- |
| id             | INTEGER | 主键                          |
| word           | TEXT    | 单词正文（汉字或假名）        |
| furigana       | TEXT    | 假名注音                      |
| romaji         | TEXT    | 罗马音                        |
| jlpt_level     | TEXT    | JLPT 等级（如 'N1', 'N2' 等） |
| part_of_speech | TEXT    | 词性（如 '名', '動I' 等）     |
| pitch_accent   | TEXT    | 音调（如 '0', '1' 等）        |

```sql
CREATE TABLE words (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    word           TEXT NOT NULL,
    furigana       TEXT,
    romaji         TEXT,
    jlpt_level     TEXT,
    part_of_speech TEXT,
    pitch_accent   TEXT
);
```

### word_meanings

| 字段             | 类型    | 说明               |
| ---------------- | ------- | ------------------ |
| id               | INTEGER | 主键               |
| word_id          | INTEGER | 关联 `words.id`    |
| meaning_cn       | TEXT    | 中文释义           |
| definition_order | INTEGER | 释义排序（默认 1） |
| notes            | TEXT    | 补充说明           |

```sql
CREATE TABLE word_meanings (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id          INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    meaning_cn       TEXT NOT NULL,
    definition_order INTEGER DEFAULT 1,
    notes            TEXT
);
```

### word_audio

| 字段           | 类型    | 说明            |
| -------------- | ------- | --------------- |
| id             | INTEGER | 主键            |
| word_id        | INTEGER | 关联 `words.id` |
| audio_filename | TEXT    | 音频文件名      |
| voice_type     | TEXT    | 发音人类型      |
| source         | TEXT    | 音频来源        |
| audio_url      | TEXT    | 远程音频 URL    |

```sql
CREATE TABLE word_audio (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id        INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    audio_filename TEXT NOT NULL,
    voice_type     TEXT,
    source         TEXT,
    audio_url      TEXT
);
```

### example_sentences

| 字段              | 类型    | 说明            |
| ----------------- | ------- | --------------- |
| id                | INTEGER | 主键            |
| word_id           | INTEGER | 关联 `words.id` |
| sentence_jp       | TEXT    | 日文例句        |
| sentence_furigana | TEXT    | 例句假名注音    |
| translation_cn    | TEXT    | 中文翻译        |
| notes             | TEXT    | 补充说明        |

```sql
CREATE TABLE example_sentences (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id           INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    sentence_jp       TEXT NOT NULL,
    sentence_furigana TEXT,
    translation_cn    TEXT,
    notes             TEXT
);
```

### example_audio

| 字段           | 类型    | 说明                         |
| -------------- | ------- | ---------------------------- |
| id             | INTEGER | 主键                         |
| example_id     | INTEGER | 关联 `example_sentences.id`  |
| audio_filename | TEXT    | 音频文件名                   |
| voice_type     | TEXT    | 发音人类型（默认 'default'） |
| source         | TEXT    | 音频来源（默认 'default'）   |
| audio_url      | TEXT    | 远程音频 URL                 |

```sql
CREATE TABLE example_audio (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    example_id     INTEGER NOT NULL REFERENCES example_sentences(id) ON DELETE CASCADE,
    audio_filename TEXT NOT NULL UNIQUE,
    voice_type     TEXT DEFAULT 'default',
    source         TEXT DEFAULT 'default',
    audio_url      TEXT
);
```

### study_words

**作用**：记录每个单词的 SRS 学习状态  
**关键枚举 (user_state)**：
- `0`: `seen` (已曝光：看过但未进入 SRS)
- `1`: `learning` (学习中)
- `2`: `mastered` (已掌握：退出 SRS)
- `3`: `ignored` (已忽略)

**关键字段说明**：
- `next_review_at`: 下一次复习时间戳（Unix 秒），NULL 表示未排期。
- `interval`: 复习间隔（天）。
- `ease_factor`: [SM-2] 难度因子（默认 2.5）。
- `stability` / `difficulty`: [FSRS] 记忆强度参数。
- `streak`: 连续答对次数。
- `total_reviews`: 累计复习次数。
- `fail_count`: 累计失败次数。


```sql
CREATE TABLE study_words (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id          INTEGER NOT NULL,
    word_id          INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    user_state       INTEGER DEFAULT 0 NOT NULL,    -- 0=未学, 1=学习中, 2=已掌握, 3=忽略
    next_review_at   INTEGER,                       -- 下次复习时间戳 (Unix)
    last_reviewed_at INTEGER,                       -- 上次复习时间戳 (Unix)
    streak           INTEGER DEFAULT 0,             -- 连续答对次数
    total_reviews    INTEGER DEFAULT 0,             -- 累计复习次数
    fail_count       INTEGER DEFAULT 0,             -- 累计失败次数
    interval         INTEGER DEFAULT 0,             -- [SM-2] 复习间隔 (天)
    ease_factor      REAL DEFAULT 2.5,              -- [SM-2] 难度因子
    stability        REAL DEFAULT 0,                -- [FSRS] 记忆稳定性 (S)
    difficulty       REAL DEFAULT 0,                -- [FSRS] 记忆难度 (D)
    created_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    UNIQUE (user_id, word_id)
);

CREATE INDEX idx_study_schedule ON study_words (user_id, user_state, next_review_at);
```

### study_logs

**作用**：不可变的学习行为日志  
**关键枚举 (log_type)**：
- `1`: 初学 (New)
- `2`: 复习 (Review)
- `3`: 掌握 (Mastered)
- `4`: 忽略 (Ignored)
- `5`: 重置 (Reset)

**关键枚举 (rating)**：
- `1`: 又记错 (Again/Hard)
- `2`: 困难 (Hard/Good)
- `3`: 良好 (Good/Easy)
- `4`: 简单 (Easy)
*(注：根据具体 SRS 算法分配映射)*

**关键枚举 (algorithm)**：
- `1`: SM-2
- `2`: FSRS

**使用原则**：只插入，不更新/删除，用于分析与调试。


```sql
CREATE TABLE study_logs (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id               INTEGER NOT NULL,
    word_id               INTEGER NOT NULL,
    question_type         TEXT,                         -- recall / audio / switchMode
    log_type              INTEGER NOT NULL,             -- 1=初学, 2=复习, 3=掌握, 4=忽略, 5=重置
    rating                INTEGER,                      -- 1=Again, 2=Hard, 3=Good, 4=Easy
    algorithm             INTEGER DEFAULT 1,            -- 1=SM-2, 2=FSRS
    interval_after        REAL,                         -- 操作后间隔
    next_review_at_after  INTEGER,                      -- 操作后复习时间
    ease_factor_after     REAL,                         -- [SM-2] 操作后 EF
    fsrs_stability_after  REAL,                         -- [FSRS] 操作后 S
    fsrs_difficulty_after REAL,                         -- [FSRS] 操作后 D
    created_at            INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL -- 创建时间
);

CREATE INDEX idx_logs_word ON study_logs (user_id, word_id, created_at);
```

### daily_stats

| 字段                       | 类型    | 说明                                    |
| -------------------------- | ------- | --------------------------------------- |
| id                         | INTEGER | 主键                                    |
| user_id                    | INTEGER | 用户 ID                                 |
| date                       | TEXT    | 日期（格式：YYYY-MM-DD）                |
| review_count               | INTEGER | 当日总复习次数                          |
| unique_kana_reviewed_count | INTEGER | 当日复习的不同假名数                    |
| new_learned_count          | INTEGER | 当日新学习数量                          |
| rating_avg                 | REAL    | 平均评分                                |
| wrong_ratio                | REAL    | 错误率                                  |
| new_interval_avg           | REAL    | 平均间隔增长                            |
| total_time_ms              | INTEGER | 总学习时长（毫秒）                      |
| first_review_at            | INTEGER | 当日首次复习时间戳                      |
| last_review_at             | INTEGER | 当日最近复习时间戳                      |
| algorithm                  | INTEGER | 使用的 SRS 算法（`1`: SM-2, `2`: FSRS） |
| learning_quality_score     | REAL    | 学习质量评分（预留）                    |

```sql
CREATE TABLE daily_stats (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id           INTEGER NOT NULL,
    date              TEXT NOT NULL,
    review_count      INTEGER DEFAULT 0,
    unique_kana_reviewed_count INTEGER DEFAULT 0,
    new_learned_count INTEGER DEFAULT 0,
    rating_avg        REAL DEFAULT 0,
    wrong_ratio       REAL DEFAULT 0,
    new_interval_avg  REAL DEFAULT 0,
    total_time_ms     INTEGER DEFAULT 0,
    first_review_at   INTEGER,
    last_review_at    INTEGER,
    algorithm         INTEGER DEFAULT 1,
    learning_quality_score REAL,
    UNIQUE(user_id, date)
);
```

### users

| 字段                 | 类型    | 说明                                 |
| -------------------- | ------- | ------------------------------------ |
| id                   | INTEGER | 主键                                 |
| username             | TEXT    | 用户名（唯一）                       |
| password_hash        | TEXT    | 密码哈希值                           |
| email                | TEXT    | 电子邮箱（唯一）                     |
| nickname             | TEXT    | 昵号                                 |
| avatar_url           | TEXT    | 头像 URL                             |
| status               | INTEGER | 账号状态（`1`: 激活, `0`: 禁用）     |
| settings             | TEXT    | JSON 格式的用户偏好设置              |
| locale               | TEXT    | 语言偏好（'zh', 'en', 'ja'）         |
| timezone             | TEXT    | 时区（如 'Asia/Shanghai'）           |
| last_active_at       | INTEGER | 上次活跃时间戳                       |
| onboarding_completed | INTEGER | 是否完成新手引导（`0`: 否, `1`: 是） |
| pro_status           | INTEGER | 会员状态（`0`: 免费, `1`: 专业版）   |
| created_at           | INTEGER | 创建时间戳                           |
| updated_at           | INTEGER | 更新时间戳                           |

```sql
CREATE TABLE users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    username        TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    email           TEXT UNIQUE,
    nickname        TEXT,
    avatar_url      TEXT,
    status          INTEGER DEFAULT 1,
    settings        TEXT,
    locale          TEXT DEFAULT 'zh',
    timezone        TEXT,
    last_active_at  INTEGER,
    onboarding_completed INTEGER DEFAULT 0,
    pro_status      INTEGER DEFAULT 0,
    created_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
);
```

### app_state

| 字段            | 类型    | 说明             |
| --------------- | ------- | ---------------- |
| id              | INTEGER | 主键（固定为 1） |
| current_user_id | INTEGER | 当前活跃用户 ID  |

```sql
CREATE TABLE app_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_user_id INTEGER REFERENCES users(id)
);
```

### word_relations

**作用**：用于语义分支学习的关联词  
**关键字段**：
- `word_id`: 源词 ID
- `related_word_id`: 关联词 ID
- `score`: 关联强度（0.0-1.0，数值越大相关性越高）
- `relation_type`: 关系类型（默认为 'semantic'，也可为 'synonym', 'antonym'）


```sql
CREATE TABLE word_relations (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id         INTEGER NOT NULL,
    related_word_id INTEGER NOT NULL,
    score           REAL NOT NULL,
    relation_type   TEXT DEFAULT 'semantic',
    FOREIGN KEY(word_id) REFERENCES words(id),
    FOREIGN KEY(related_word_id) REFERENCES words(id)
);

CREATE INDEX idx_word_relations_word_id ON word_relations (word_id, score DESC);
CREATE INDEX idx_word_relations_related_word_id ON word_relations (related_word_id);
```

---

## 单词变形相关表

### conjugation_types

| 字段        | 类型    | 说明                              |
| ----------- | ------- | --------------------------------- |
| id          | INTEGER | 主键                              |
| code        | TEXT    | 变形类型编码（如 'te', 'nai' 等） |
| name_ja     | TEXT    | 日文名称（如 'て形'）             |
| name_cn     | TEXT    | 中文名称                          |
| sort_order  | INTEGER | 显示排序                          |
| description | TEXT    | 变形规则描述                      |

```sql
CREATE TABLE conjugation_types (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,
    name_ja     TEXT NOT NULL,
    name_cn     TEXT NOT NULL,
    sort_order  INTEGER DEFAULT 0,
    description TEXT
);
```

### word_conjugations

| 字段            | 类型    | 说明                        |
| --------------- | ------- | --------------------------- |
| id              | INTEGER | 主键                        |
| word_id         | INTEGER | 关联 `words.id`             |
| type_id         | INTEGER | 关联 `conjugation_types.id` |
| conjugated_word | TEXT    | 变形后的单词正文            |
| furigana        | TEXT    | 变形后的假名注音            |
| accent_pattern  | TEXT    | 变形后的声调                |

```sql
CREATE TABLE word_conjugations (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id        INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    type_id        INTEGER NOT NULL REFERENCES conjugation_types(id) ON DELETE CASCADE,
    conjugated_word TEXT NOT NULL,
    furigana       TEXT,
    accent_pattern TEXT,
    UNIQUE(word_id, type_id)
);
```

---

## 假名学习相关表

### kana_letters

| 字段          | 类型    | 说明                                                   |
| ------------- | ------- | ------------------------------------------------------ |
| id            | INTEGER | 主键                                                   |
| kana_char     | TEXT    | 假名字符（如 'あ'）                                    |
| script_kind   | TEXT    | 脚本类型（'hiragana': 平假名, 'katakana': 片假名）     |
| romaji        | TEXT    | 罗马音                                                 |
| consonant     | TEXT    | 辅音                                                   |
| vowel         | TEXT    | 元音                                                   |
| row_group     | TEXT    | 行分组（如 'あ行', 'か行'）                            |
| kana_category | TEXT    | 假名类型（'清音', '濁音', '半濁音', '拗音', '外来音'） |
| display_order | INTEGER | 排序索引                                               |
| pair_group_id | INTEGER | 平片假名配对组 ID                                      |
| audio_id      | INTEGER | 关联 `kana_audio.id`                                   |
| mnemonic      | TEXT    | 助记说明                                               |
| created_at    | TEXT    | 创建时间（ISO 8601 格式）                              |
| updated_at    | TEXT    | 更新时间                                               |

```sql
CREATE TABLE kana_letters (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_char         TEXT NOT NULL,
    script_kind       TEXT NOT NULL,
    romaji            TEXT NOT NULL,
    consonant         TEXT,
    vowel             TEXT NOT NULL,
    row_group         TEXT,
    kana_category     TEXT,
    display_order     INTEGER,
    pair_group_id     INTEGER,
    audio_id          INTEGER REFERENCES kana_audio(id),
    mnemonic          TEXT,
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL
);
```

### kana_audio

| 字段           | 类型    | 说明       |
| -------------- | ------- | ---------- |
| id             | INTEGER | 主键       |
| audio_filename | TEXT    | 音频文件名 |
| audio_source   | TEXT    | 音频来源   |
| created_at     | TEXT    | 创建时间   |

```sql
CREATE TABLE kana_audio (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    audio_filename TEXT NOT NULL,
    audio_source   TEXT,
    created_at     TEXT NOT NULL
);
```

### kana_examples

| 字段             | 类型    | 说明                   |
| ---------------- | ------- | ---------------------- |
| id               | INTEGER | 主键                   |
| kana_id          | INTEGER | 关联 `kana_letters.id` |
| example_jp       | TEXT    | 日语示例词             |
| example_furigana | TEXT    | 示例词假名注音         |
| example_cn       | TEXT    | 示例词中文翻译         |
| created_at       | TEXT    | 创建时间               |

```sql
CREATE TABLE kana_examples (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id          INTEGER REFERENCES kana_letters(id),
    example_jp       TEXT,
    example_furigana TEXT,
    example_cn       TEXT,
    created_at       TEXT
);
```

### kana_learning_state

**作用**：假名学习进度（对应 `LearningStatus` 枚举）
- `0`: `seen` (已曝光)
- `1`: `learning` (学习中)
- `2`: `mastered` (已掌握)
- `3`: `ignored` (已忽略)


```sql
CREATE TABLE kana_learning_state (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id          INTEGER NOT NULL REFERENCES users(id),
    kana_id          INTEGER NOT NULL REFERENCES kana_letters(id),

    learning_status  INTEGER DEFAULT 0 NOT NULL,    -- 0=未学, 1=学习中, 2=已掌握, 3=忽略

    next_review_at   INTEGER,                       -- 下次复习时间 (Unix)
    last_reviewed_at INTEGER,                       -- 上次复习时间 (Unix)

    streak           INTEGER DEFAULT 0,             -- 连续答对次数
    total_reviews    INTEGER DEFAULT 0,             -- 累计复习次数
    fail_count       INTEGER DEFAULT 0,             -- 累计失败次数

    interval         REAL DEFAULT 0,                -- SM-2 复习间隔 (天)
    ease_factor      REAL DEFAULT 2.5,              -- 难度系数

    stability        REAL DEFAULT 0,                -- FSRS 记忆稳定性 (S)
    difficulty       REAL DEFAULT 0,                -- 记忆难度 (D)

    created_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at       INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,

    UNIQUE (user_id, kana_id)
);

CREATE INDEX idx_kana_review_schedule
ON kana_learning_state (user_id, learning_status, next_review_at);
```


### kana_stroke_order

| 字段    | 类型    | 说明                   |
| ------- | ------- | ---------------------- |
| id      | INTEGER | 主键                   |
| kana_id | INTEGER | 关联 `kana_letters.id` |
| svg     | TEXT    | 笔顺 SVG 数据          |

```sql
CREATE TABLE kana_stroke_order (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id    INTEGER NOT NULL UNIQUE REFERENCES kana_letters(id),
    svg        TEXT
);
```

---

## 语法学习相关表

> 语法采用四层基础数据结构 + 一层学习状态：`grammars`（语法条目）→ `grammar_meanings`（义项）/ `grammar_contexts`（场景/限制）→ `grammar_examples`（例句）。
> 一条语法可以有多个义项、多个场景描述和多条例句。

### grammars

| 字段            | 类型    | 说明                         |
| --------------- | ------- | ---------------------------- |
| id              | INTEGER | 主键                         |
| title           | TEXT    | 语法标题（如 '~ていきます'） |
| jlpt_level      | TEXT    | JLPT 等级（'N1'-'N5'）       |
| usage_frequency | INTEGER | 使用频率/重要度              |
| created_at      | INTEGER | 创建时间戳                   |
| updated_at      | INTEGER | 更新时间戳                   |

```sql
CREATE TABLE grammars (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    title            TEXT NOT NULL,
    jlpt_level       TEXT,
    usage_frequency  INTEGER DEFAULT 0,
    created_at       INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at       INTEGER DEFAULT (strftime('%s', 'now'))
);
```

### grammar_meanings

| 字段          | 类型    | 说明               |
| ------------- | ------- | ------------------ |
| id            | INTEGER | 主键               |
| grammar_id    | INTEGER | 关联 `grammars.id` |
| sort_order    | INTEGER | 义项排序（默认 1） |
| definition_cn | TEXT    | 中文义项定义       |
| definition_en | TEXT    | 英文义项定义       |
| how_to_use_cn | TEXT    | 中文接续方法说明   |
| how_to_use_en | TEXT    | 英文接续方法说明   |

```sql
CREATE TABLE grammar_meanings (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    grammar_id    INTEGER NOT NULL REFERENCES grammars(id),
    sort_order    INTEGER DEFAULT 1,
    definition_cn TEXT,
    definition_en TEXT,
    how_to_use_cn TEXT,
    how_to_use_en TEXT
);
```

### grammar_contexts

| 字段           | 类型    | 说明                      |
| -------------- | ------- | ------------------------- |
| id             | INTEGER | 主键                      |
| grammar_id     | INTEGER | 关联 `grammars.id`        |
| when_to_use_cn | TEXT    | 使用场景/时机说明（中文） |
| when_to_use_en | TEXT    | 使用场景/时机说明（英文） |

```sql
CREATE TABLE grammar_contexts (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    grammar_id     INTEGER NOT NULL REFERENCES grammars(id),
    when_to_use_cn TEXT,
    when_to_use_en TEXT
);
```

### grammar_examples

| 字段           | 类型    | 说明                               |
| -------------- | ------- | ---------------------------------- |
| id             | INTEGER | 主键                               |
| grammar_id     | INTEGER | 关联 `grammars.id`                 |
| sort_order     | INTEGER | 例句排序（默认 1）                 |
| sentence       | TEXT    | 日文例句（可能包含 Ruby 标注格式） |
| translation_cn | TEXT    | 中文翻译                           |
| translation_en | TEXT    | 英文翻译                           |
| audio_url      | TEXT    | 音频文件路径或 URL                 |

```sql
CREATE TABLE grammar_examples (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    grammar_id     INTEGER NOT NULL REFERENCES grammars(id),
    sort_order     INTEGER DEFAULT 1,
    sentence       TEXT,
    translation_cn TEXT,
    translation_en TEXT,
    audio_url      TEXT
);
```

### study_grammars

| 字段             | 类型    | 说明                                                              |
| ---------------- | ------- | ----------------------------------------------------------------- |
| id               | INTEGER | 主键                                                              |
| user_id          | INTEGER | 用户 ID                                                           |
| grammar_id       | INTEGER | 关联 `grammars.id`                                                |
| learning_status  | INTEGER | 学习状态（`0`: seen, `1`: learning, `2`: mastered, `3`: ignored） |
| next_review_at   | INTEGER | 下次复习时间戳                                                    |
| last_reviewed_at | INTEGER | 上次复习时间戳                                                    |
| streak           | INTEGER | 连续答对次数                                                      |
| total_reviews    | INTEGER | 累计复习次数                                                      |
| fail_count       | INTEGER | 累计失败次数                                                      |
| interval         | REAL    | 复习间隔（天）                                                    |
| ease_factor      | REAL    | 难度因子                                                          |
| stability        | REAL    | [FSRS] 稳定性                                                     |
| difficulty       | REAL    | [FSRS] 难度                                                       |
| created_at       | INTEGER | 创建时间戳                                                        |
| updated_at       | INTEGER | 更新时间戳                                                        |

```sql
CREATE TABLE study_grammars (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id          INTEGER NOT NULL,
    grammar_id       INTEGER NOT NULL REFERENCES grammars(id),
    learning_status  INTEGER DEFAULT 0,
    next_review_at   INTEGER,
    last_reviewed_at INTEGER,
    streak           INTEGER DEFAULT 0,
    total_reviews    INTEGER DEFAULT 0,
    fail_count       INTEGER DEFAULT 0,
    interval         REAL DEFAULT 0,
    ease_factor      REAL DEFAULT 2.5,
    stability        REAL DEFAULT 0,
    difficulty       REAL DEFAULT 0,
    created_at       INTEGER,
    updated_at       INTEGER,
    UNIQUE(user_id, grammar_id)
);
```

## 实体关系

### 单词学习模块

```
words (1) ──< (N) word_meanings
      (1) ──< (N) word_audio
      (1) ──< (N) example_sentences (1) ──< (N) example_audio
      (1) ──< (N) study_words (N) >── (1) users
      (1) ──< (N) study_logs  (N) >── (1) users
      (1) ──< (N) word_relations (N) >── (1) words (related words)
      (1) ──< (N) word_conjugations (N) >── (1) conjugation_types

users (1) ──< (N) daily_stats
      (1) ──< (1) app_state (singleton, current_user_id)
```

### 语法学习模块

```
grammars (1) ──< (N) grammar_meanings
         (1) ──< (N) grammar_contexts
         (1) ──< (N) grammar_examples
         (1) ──< (N) study_grammars (N) >── (1) users
```

### 假名学习模块

```
kana_letters (N) >── (1) kana_audio (via audio_id)
             (1) ──< (N) kana_examples
             (1) ──< (1) kana_learning_state (per user)
             (1) ──< (1) kana_stroke_order
```

## Repository 实现规范

### 模型类要求

每张表必须在 `lib/data/models/` 下有对应模型：

```dart
class Word {
  final int id;
  final String word;
  final String? furigana;
  final String? romaji;
  final String? jlptLevel;  // 数据库为 jlpt_level

  Word({required this.id, required this.word, ...});

  // 从数据库行构造
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int,
      word: map['word'] as String,
      furigana: map['furigana'] as String?,
      jlptLevel: map['jlpt_level'] as String?, // snake_case → camelCase
    );
  }

  // 写回数据库行
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'furigana': furigana,
      'jlpt_level': jlptLevel, // camelCase → snake_case
    };
  }
}
```

### Repository 模式示例（CRUD only）

示例为 Repository 内部用法（Query / Analytics 不使用 `AppDatabase.instance`）。

```dart
class WordRepository {
  // ✅ 正确：单表 CRUD，返回模型对象
  Future<Word?> getWordById(int id) async {
    final db = await AppDatabase.instance.database;
    final results = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Word.fromMap(results.first);
  }

  // ❌ 错误：不要返回 Map
  Future<List<Map<String, dynamic>>> getWords() async { ... }
}
```

### 时间戳读写

```dart
// 数据库存秒，Dart 用毫秒

// 读取
final ts = map['created_at'] as int;
final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);

// 写入
final nowSeconds = (DateTime.now().millisecondsSinceEpoch / 1000).round();
```

### 获取当前用户

```dart
final userId = await ref.read(activeUserQueryProvider).getActiveUserId();
```
