---
inclusion: always
---

# 数据库模式参考

## 概览

**数据库**：位于 `assets/database/breeze_jp.sqlite` 的本地 SQLite  
**访问方式**：Repository 内部使用 `AppDatabase.instance`，Query / Analytics 通过 `databaseProvider` 注入 Database（Controller / Debug 不直接访问）  
**18 张核心表**：

- **单词学习**：words、word_meanings、word_audio、example_sentences、example_audio、word_relations
- **语法学习**：grammars, grammar_examples
- **用户进度**：study_words、study_grammars, study_logs、daily_stats、users、app_state
- **假名学习**：kana_letters、kana_audio、kana_examples、kana_learning_state、kana_stroke_order

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

```sql
CREATE TABLE word_meanings (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id          INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    meaning_cn       TEXT NOT NULL,
    definition_order INTEGER DEFAULT 1,
    notes            TEXT
);

CREATE INDEX idx_meanings_word_id ON word_meanings (word_id);
```

### word_audio

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

```sql
CREATE TABLE example_sentences (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id           INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    sentence_jp       TEXT NOT NULL,
    sentence_furigana TEXT,
    translation_cn    TEXT,
    notes             TEXT
);

CREATE INDEX idx_examples_word_id ON example_sentences (word_id);
```

### example_audio

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
**关键字段**：

- `user_state`: 0=未学, 1=学习中, 2=已掌握, 3=忽略
- `next_review_at`: 下一次复习时间戳（NULL 表示未排期）
- `interval`: SM-2 间隔（天）
- `ease_factor`: SM-2 难度系数（默认 2.5）
- `stability`、`difficulty`: FSRS 参数（默认 0）

**常用查询**：

```sql
-- 获取待复习单词
SELECT * FROM study_words
WHERE user_id = ? AND user_state = 1 AND next_review_at <= ?

-- 语义分支学习：获取可学单词
SELECT w.* FROM words w
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
WHERE sw.user_state IS NULL OR sw.user_state IN (0, 1)
```

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
**关键字段**：

- `log_type`: 1=初学, 2=复习, 3=掌握, 4=忽略, 5=重置
- `rating`: 1=Again, 2=Hard, 3=Good, 4=Easy（非复习操作可为 NULL）
- `algorithm`: 1=SM-2, 2=FSRS
- `*_after`: 记录操作后的 SRS 状态快照

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

```sql
CREATE TABLE daily_stats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date TEXT NOT NULL,         -- YYYY-MM-DD

  review_count INTEGER DEFAULT 0,            -- 总复习次数
  unique_kana_reviewed_count INTEGER DEFAULT 0,   -- 当天复习的不同假名数
  new_learned_count INTEGER DEFAULT 0,       -- 新学习数量

  rating_avg REAL DEFAULT 0,                 -- 平均评分
  wrong_ratio REAL DEFAULT 0,                -- 错误率
  new_interval_avg REAL DEFAULT 0,           -- 平均间隔增长

  total_time_ms INTEGER DEFAULT 0,           -- 总复习时长
  first_review_at INTEGER,                   -- 当天首次复习时间戳
  last_review_at INTEGER,                    -- 当天最近复习时间戳

  algorithm INTEGER DEFAULT 1,               -- 当天使用 SRS 算法（1/2）

  learning_quality_score REAL,               -- 学习质量评分

  UNIQUE(user_id, date)
);
```

### users

```sql
CREATE TABLE users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    username        TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    email           TEXT UNIQUE,
    nickname        TEXT,
    avatar_url      TEXT,

    status          INTEGER DEFAULT 1,    -- 1=active, 0=inactive

    settings        TEXT,                 -- JSON 用户偏好设置
    locale          TEXT DEFAULT 'zh',    -- 语言偏好 zh/en/ja
    timezone        TEXT,                 -- Asia/Shanghai 等
    last_active_at  INTEGER,              -- 上次活跃时间戳
    onboarding_completed INTEGER DEFAULT 0,
    pro_status      INTEGER DEFAULT 0,    -- 0=Free, 1=Pro

    created_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at      INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
);
```

```sql
CREATE TABLE app_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_user_id INTEGER REFERENCES users(id)    --- 当前活跃用户 ID
);
```

### word_relations

**作用**：用于语义分支学习的关联词  
**模型类**：无独立 `WordRelation` 模型，查询结果使用 `WordWithRelation` DTO（包含 `Word` + `score` + `relationType`）

**关键字段**：

- `word_id`: 源词
- `related_word_id`: 关联词
- `score`: 关联强度（越大越相关）
- `relation_type`: 如 semantic / synonym / antonym

**常用查询**：获取全部关联词

```sql
SELECT w.*, wr.score, wr.relation_type
FROM word_relations wr
JOIN words w ON wr.related_word_id = w.id
LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
WHERE wr.word_id = ?
  AND (sw.user_state IS NULL OR sw.user_state IN (0, 1))
ORDER BY wr.score DESC;
```

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

## 假名学习相关表

### kana_letters（母表）

```sql
CREATE TABLE kana_letters (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_char      TEXT,                              -- 假名字符 (如 あ / ア)
    script_kind    TEXT,                              -- 脚本类型 (hiragana / katakana)
    romaji         TEXT,                              -- 罗马音 (如 a)
    consonant      TEXT,                              -- 辅音 (如 k, s, t)
    vowel          TEXT,                              -- 元音 (如 a, i, u, e, o)
    row_group      TEXT,                              -- 行分组 (如 あ行, か行)
    kana_category  TEXT,                              -- 类型 (清音/濁音/半濁音/拗音/外来音)
    display_order  INTEGER,                           -- 排序索引
    pair_group_id  INTEGER,                           -- 平片假名配对组 ID
    audio_id       INTEGER,                           -- 关联音频 ID
    mnemonic       TEXT,                              -- 记忆助记词
    created_at     TEXT,
    updated_at     TEXT
);
```

### kana_audio

```sql
CREATE TABLE kana_audio (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    audio_filename TEXT,                                  -- 音频文件名
    audio_source   TEXT,                                  -- 音频来源
    created_at     TEXT
);
```

### kana_examples

```sql
CREATE TABLE kana_examples (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id          INTEGER REFERENCES kana_letters(id),  -- 关联假名
    example_jp       TEXT,                                  -- 日语示例词
    example_furigana TEXT,                                  -- 假名注音
    example_cn       TEXT,                                  -- 中文翻译
    created_at       TEXT
);
```

### kana_learning_state

**作用**：假名学习进度（结构与 `study_words` 基本一致）

- `learning_status`: 0=未学习, 1=学习中, 2=已掌握, 3=忽略
- 兼容 SM-2 与 FSRS

**常用查询**：获取待复习假名

```sql
SELECT * FROM kana_learning_state
WHERE user_id = ? AND learning_status = 1 AND next_review_at <= ?
```

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

```sql
CREATE TABLE kana_stroke_order (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id    INTEGER REFERENCES kana_letters(id),  -- 关联假名
    svg TEXT
);
```

---

## 语法学习相关表

### grammars

```sql
CREATE TABLE grammars (
    id           INTEGER PRIMARY KEY,
    title        TEXT NOT NULL,                     -- 语法标题 (如 〜に関して)
    meaning      TEXT,                              -- 含义
    connection   TEXT,                              -- 接续 (如 名詞 + に関して)
    jlpt_level   TEXT,                              -- JLPT 等级
    tags         TEXT,                              -- 标签 (词性、分类等)
    created_at   INTEGER,
    updated_at   INTEGER
);
```

### grammar_examples

```sql
CREATE TABLE grammar_examples (
    id           INTEGER PRIMARY KEY,
    grammar_id   INTEGER NOT NULL REFERENCES grammars(id),
    sentence     TEXT,                              -- 日文例句
    translation  TEXT,                              -- 中文翻译
    audio_url    TEXT,                              -- 音频路径
    created_at   INTEGER
);
```

### study_grammars

**作用**：记录语法的 FSRS 学习状态 (结构类似 `study_words`)

```sql
CREATE TABLE study_grammars (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id          INTEGER NOT NULL,
    grammar_id       INTEGER NOT NULL REFERENCES grammars(id),
    learning_status  INTEGER DEFAULT 0,             -- 0=未学, 1=学习中, 2=已掌握, 3=忽略
    next_review_at   INTEGER,                       -- 下次复习时间戳
    last_reviewed_at INTEGER,                       -- 上次复习时间戳
    streak           INTEGER DEFAULT 0,
    total_reviews    INTEGER DEFAULT 0,
    fail_count       INTEGER DEFAULT 0,
    interval         REAL DEFAULT 0,                -- 间隔 (天)
    ease_factor      REAL DEFAULT 2.5,              -- 难度因子
    stability        REAL DEFAULT 0,                -- [FSRS] 稳定性
    difficulty       REAL DEFAULT 0,                -- [FSRS] 难度
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

users (1) ──< (N) daily_stats
      (1) ──< (1) app_state (singleton, current_user_id)
```

### 语法学习模块

```
grammars (1) ──< (N) grammar_examples
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
