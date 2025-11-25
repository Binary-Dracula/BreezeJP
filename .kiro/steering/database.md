---
inclusion: always
---

# 数据库架构

BreezeJP 使用 SQLite 本地数据库（`assets/database/breeze_jp.sqlite`），包含 9 个核心表。

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
    user_state       INTEGER DEFAULT 0 NOT NULL,
    next_review_at   INTEGER,
    last_reviewed_at INTEGER,
    streak           INTEGER DEFAULT 0,
    total_reviews    INTEGER DEFAULT 0,
    fail_count       INTEGER DEFAULT 0,
    interval         REAL DEFAULT 0,
    ease_factor      REAL DEFAULT 2.5,
    stability        REAL DEFAULT 0,
    difficulty       REAL DEFAULT 0,
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
    log_type              INTEGER NOT NULL,
    rating                INTEGER,
    algorithm             INTEGER DEFAULT 1,
    interval_after        REAL,
    next_review_at_after  INTEGER,
    ease_factor_after     REAL,
    fsrs_stability_after  REAL,
    fsrs_difficulty_after REAL,
    duration_ms           INTEGER DEFAULT 0,
    created_at            INTEGER DEFAULT (strftime('%s', 'now')) NOT NULL
);

CREATE INDEX idx_logs_word ON study_logs (user_id, word_id, created_at);
```

### daily_stats
```sql
CREATE TABLE daily_stats (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id              INTEGER NOT NULL,
    date                 TEXT NOT NULL,
    total_study_time_ms  INTEGER DEFAULT 0,
    learned_words_count  INTEGER DEFAULT 0,
    reviewed_words_count INTEGER DEFAULT 0,
    mastered_words_count INTEGER DEFAULT 0,
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

## 数据关系

```
words (1) ──< (N) word_meanings
      (1) ──< (N) word_audio
      (1) ──< (N) example_sentences (1) ──< (N) example_audio
      (1) ──< (N) study_words (N) >── (1) users
      (1) ──< (N) study_logs  (N) >── (1) users
                                     (1) ──< (N) daily_stats
```
