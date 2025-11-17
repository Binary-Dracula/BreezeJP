---
inclusion: always
---

# 数据库架构

BreezeJP 使用 SQLite 本地数据库（`assets/database/breeze_jp.sqlite`），包含 5 个核心表。

## 表结构总览

1. `words` - 单词核心信息
2. `word_meanings` - 单词释义（一对多）
3. `word_audio` - 单词音频文件（一对多）
4. `example_sentences` - 例句（一对多）
5. `example_audio` - 例句音频文件（一对多）

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
| voice_type | TEXT | 音频类型，如 default / NHK / other |
| source | TEXT | 来源，如 default / NHK / TTS |

**音频文件路径**：`assets/audio/words/[audio_filename]`

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
| voice_type | TEXT DEFAULT 'default' | 音频类型 |
| source | TEXT DEFAULT 'default' | 来源 |

**音频文件路径**：`assets/audio/examples/[audio_filename]`

## 数据关系

```
words (1) ──< (N) word_meanings
      (1) ──< (N) word_audio
      (1) ──< (N) example_sentences (1) ──< (N) example_audio
```

- 所有外键使用 `ON DELETE CASCADE`，删除单词时自动清理关联数据
- `words` 是核心表，其他表通过 `word_id` 或 `example_id` 关联

## 常见查询模式

### 查询单词及其释义
```sql
SELECT w.*, wm.meaning_cn 
FROM words w
LEFT JOIN word_meanings wm ON w.id = wm.word_id
WHERE w.jlpt_level = 'N5'
ORDER BY wm.definition_order;
```

### 查询单词的例句和音频
```sql
SELECT es.*, ea.audio_filename
FROM example_sentences es
LEFT JOIN example_audio ea ON es.id = ea.example_id
WHERE es.word_id = ?;
```

### 获取单词音频
```sql
SELECT audio_filename FROM word_audio WHERE word_id = ? LIMIT 1;
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