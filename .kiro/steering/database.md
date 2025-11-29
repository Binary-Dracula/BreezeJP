---
inclusion: always
---

# 数据库架构

BreezeJP 使用 SQLite 本地数据库（`assets/database/breeze_jp.sqlite`），包含 16 个核心表。

- **单词学习相关**：words, word_meanings, word_audio, example_sentences, example_audio, word_relations
- **学习进度相关**：study_words, study_logs, daily_stats, users
- **五十音图学习相关**：kana_letters, kana_audio, kana_examples, kana_learning_state, kana_quiz_records, kana_stroke_order

## 表结构

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
    interval         REAL DEFAULT 0,                -- [SM-2] 复习间隔 (天)
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
```sql
CREATE TABLE study_logs (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id               INTEGER NOT NULL,
    word_id               INTEGER NOT NULL,
    log_type              INTEGER NOT NULL,             -- 1=初学, 2=复习, 3=掌握, 4=忽略, 5=重置
    rating                INTEGER,                      -- 1=Hard, 2=Good, 3=Easy
    algorithm             INTEGER DEFAULT 1,            -- 1=SM-2, 2=FSRS
    interval_after        REAL,                         -- 操作后间隔
    next_review_at_after  INTEGER,                      -- 操作后复习时间
    ease_factor_after     REAL,                         -- [SM-2] 操作后 EF
    fsrs_stability_after  REAL,                         -- [FSRS] 操作后 S
    fsrs_difficulty_after REAL,                         -- [FSRS] 操作后 D
    duration_ms           INTEGER DEFAULT 0,            -- 学习耗时 (毫秒)
    created_at            INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL -- 创建时间
);

CREATE INDEX idx_logs_word ON study_logs (user_id, word_id, created_at);
```

### daily_stats
```sql
CREATE TABLE daily_stats (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id              INTEGER NOT NULL,
    date                 TEXT NOT NULL,                     -- 日期 (YYYY-MM-DD)
    total_study_time_ms  INTEGER DEFAULT 0,                 -- 总学习时长 (毫秒)
    learned_words_count  INTEGER DEFAULT 0,                 -- 新学单词数
    reviewed_words_count INTEGER DEFAULT 0,                 -- 手动掌握数
    mastered_words_count INTEGER DEFAULT 0,                 -- 失败/忘记次数
    failed_count         INTEGER DEFAULT 0,
    created_at           INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at           INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    UNIQUE (user_id, date)
);
```

### users
```sql
CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email         TEXT UNIQUE,
    nickname      TEXT,
    avatar_url    TEXT,
    status        INTEGER DEFAULT 1,
    created_at    INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL,
    updated_at    INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
);
```

### word_relations
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

## 五十音图学习表

### kana_letters
五十音字母主表，存储平假名、片假名及其属性。
```sql
CREATE TABLE kana_letters (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    hiragana   TEXT,                              -- 平假名 (如 あ)
    katakana   TEXT,                              -- 片假名 (如 ア)
    romaji     TEXT,                              -- 罗马音 (如 a)
    consonant  TEXT,                              -- 辅音 (如 k, s, t)
    vowel      TEXT,                              -- 元音 (如 a, i, u, e, o)
    kana_group TEXT,                              -- 行分组 (如 あ行, か行)
    type       TEXT,                              -- 类型 (basic/dakuten/handakuten/combo)
    sort_index INTEGER,                           -- 排序索引
    mnemonic   TEXT,                              -- 记忆助记词
    created_at TEXT,
    updated_at TEXT
);
```

### kana_audio
五十音发音音频。
```sql
CREATE TABLE kana_audio (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id        INTEGER REFERENCES kana_letters(id),  -- 关联假名
    audio_filename TEXT,                                  -- 音频文件名
    source         TEXT,                                  -- 音频来源
    created_at     TEXT
);
```

### kana_examples
五十音示例词汇，用于辅助记忆。
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
用户五十音学习状态，支持 SRS 复习。
```sql
CREATE TABLE kana_learning_state (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id     INTEGER REFERENCES kana_letters(id),  -- 关联假名
    is_learned  INTEGER DEFAULT 0,                    -- 是否已学习 (0=未学, 1=已学)
    last_review TEXT,                                 -- 上次复习时间
    next_review TEXT,                                 -- 下次复习时间
    easiness    REAL DEFAULT 2.5,                     -- SM-2 难度因子
    interval    INTEGER DEFAULT 0                     -- 复习间隔 (天)
);
```

### kana_quiz_records
五十音测验记录。
```sql
CREATE TABLE kana_quiz_records (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id    INTEGER REFERENCES kana_letters(id),  -- 关联假名
    correct    INTEGER,                               -- 是否正确 (0=错误, 1=正确)
    created_at TEXT                                   -- 测验时间
);
```

### kana_stroke_order
五十音笔顺数据。
```sql
CREATE TABLE kana_stroke_order (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    kana_id    INTEGER REFERENCES kana_letters(id),  -- 关联假名
    stroke_svg TEXT,                                  -- SVG 笔顺数据
    created_at TEXT
);
```

## 数据关系

### 单词学习模块
```
words (1) ──< (N) word_meanings
      (1) ──< (N) word_audio
      (1) ──< (N) example_sentences (1) ──< (N) example_audio
      (1) ──< (N) study_words (N) >── (1) users
      (1) ──< (N) study_logs  (N) >── (1) users
      (1) ──< (N) word_relations (N) >── (1) words (关联单词)
                                     (1) ──< (N) daily_stats
```

### 五十音图学习模块
```
kana_letters (1) ──< (N) kana_audio           -- 发音音频
             (1) ──< (N) kana_examples        -- 示例词汇
             (1) ──< (1) kana_learning_state  -- 学习状态
             (1) ──< (N) kana_quiz_records    -- 测验记录
             (1) ──< (1) kana_stroke_order    -- 笔顺数据
```
