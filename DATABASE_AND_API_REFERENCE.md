# BreezeJP 数据库与 API 参考文档

> 生成日期: 2026-05-16

---

## 一、数据库概况

BreezeJP 使用双层数据库架构：
- **本地 SQLite** (`assets/database/breeze_jp.sqlite`)：客户端离线数据库，用于本地存储和离线学习
- **云端 Supabase (PostgreSQL)** (`api/supabase/schema.sql`)：服务端数据库，通过 Cloudflare Workers 提供 REST API

两张 schema 共享大部分表结构（本地 SQLite 是 Supabase 表的子集镜像），但 Supabase 端包含额外的用户系统表、RLS 策略和 PostgreSQL 函数。

---

## 二、本地 SQLite 数据库表结构

### 2.1 用户相关

#### `users` — 用户账号表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `username` | TEXT UNIQUE | 用户名，唯一 |
| `password_hash` | TEXT | 密码哈希 |
| `email` | TEXT UNIQUE | 邮箱，唯一 |
| `nickname` | TEXT | 昵称 |
| `avatar_url` | TEXT | 头像 URL |
| `status` | INTEGER DEFAULT 1 | 状态：1=活跃, 0=停用 |
| `settings` | TEXT | JSON 格式用户偏好设置 |
| `locale` | TEXT DEFAULT 'zh' | 语言偏好：zh/en/ja |
| `timezone` | TEXT | 时区，如 Asia/Shanghai |
| `last_active_at` | INTEGER | 上次活跃时间戳 |
| `onboarding_completed` | INTEGER DEFAULT 0 | 是否完成引导 |
| `pro_status` | INTEGER DEFAULT 0 | 会员状态：0=Free, 1=Pro |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

#### `app_state` — 应用状态表（单行）
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK CHECK(id=1) | 固定为 1 |
| `current_user_id` | INTEGER | 当前登录用户 ID → users.id |

---

### 2.2 假名系统 (Kana)

#### `kana_letters` — 假名字母表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `kana_char` | TEXT | 假名字符（如 あ、ア） |
| `script_kind` | TEXT | 文字类型：hiragana/katakana |
| `romaji` | TEXT | 罗马音拼写 |
| `consonant` | TEXT | 辅音 |
| `vowel` | TEXT | 元音 |
| `row_group` | TEXT | 行分组（如 あ行、か行） |
| `kana_category` | TEXT | 假名分类 |
| `display_order` | INTEGER | 显示排序 |
| `pair_group_id` | INTEGER | 平假/片假配对组 ID |
| `audio_id` | INTEGER | 音频 ID → kana_audio.id |
| `mnemonic` | TEXT | 记忆法提示 |
| `created_at` | TEXT | 创建时间 |
| `updated_at` | TEXT | 更新时间 |

#### `kana_audio` — 假名音频表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `audio_filename` | TEXT | 音频文件名 |
| `audio_source` | TEXT | 音频来源 |
| `created_at` | TEXT | 创建时间 |

#### `kana_stroke_order` — 假名笔顺表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `kana_id` | INTEGER UNIQUE | 假名 ID → kana_letters.id |
| `svg` | TEXT | SVG 笔顺数据 |

#### `kana_examples` — 假名示例词表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `kana_id` | INTEGER | 假名 ID → kana_letters.id |
| `example_jp` | TEXT | 日文示例词 |
| `example_furigana` | TEXT | 振假名注音 |
| `example_cn` | TEXT | 中文翻译 |
| `created_at` | TEXT | 创建时间 |

#### `kana_learning_state` — 假名学习状态表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `user_id` | INTEGER | 用户 ID → users.id |
| `kana_id` | INTEGER | 假名 ID → kana_letters.id |
| `learning_status` | INTEGER DEFAULT 0 | 学习状态：0=未学, 1=学习中, 2=已掌握, 3=忽略 |
| `next_review_at` | INTEGER | 下次复习时间戳 |
| `last_reviewed_at` | INTEGER | 上次复习时间戳 |
| `streak` | INTEGER DEFAULT 0 | 连续正确次数 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习次数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败次数 |
| `interval` | REAL DEFAULT 0 | SM-2 间隔 |
| `ease_factor` | REAL DEFAULT 2.5 | SM-2 易度因子 |
| `stability` | REAL DEFAULT 0 | FSRS 稳定性 |
| `difficulty` | REAL DEFAULT 0 | FSRS 难度 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

> UNIQUE (user_id, kana_id)

---

### 2.3 单词系统 (Words)

#### `words` — 单词主表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | UUID（来自 Supabase） |
| `word` | TEXT | 目标单词（如 気づく） |
| `reading` | TEXT | 假名读音（如 きづく） |
| `romaji` | TEXT | 罗马音 |
| `pitch_accent` | TEXT | 声调标注 |
| `jlpt_level` | TEXT | JLPT 等级（n1-n5） |
| `part_of_speech` | TEXT | 词性 |
| `transitivity` | TEXT | 自/他动词标注 |
| `primary_meaning` | TEXT | 首要中文释义 |
| `has_audio` | INTEGER DEFAULT 0 | 是否有音频 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

#### `word_details` — 单词深度内容表
| 字段 | 类型 | 说明 |
|------|------|------|
| `word_id` | TEXT PK | 单词 ID → words.id (CASCADE) |
| `rich_content` | TEXT (JSON) | 丰富内容 JSON：meanings, grammar_rules, conjugations 等 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

#### `word_examples` — 单词例句表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | UUID（来自 Supabase） |
| `word_id` | TEXT | 单词 ID → words.id (CASCADE) |
| `level` | TEXT DEFAULT 'Casual' | 语体级别：Casual/Polite/Business |
| `japanese` | TEXT | 日文例句（含 ruby 注音） |
| `chinese` | TEXT | 中文翻译 |
| `has_audio` | INTEGER DEFAULT 0 | 是否有音频 |
| `sort_order` | INTEGER DEFAULT 0 | 排序 |
| `created_at` | INTEGER | 创建时间戳 |

#### `study_words` — 用户单词学习状态表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `user_id` | INTEGER | 用户 ID → users.id |
| `word_id` | TEXT | 单词 ID → words.id (CASCADE) |
| `book_id` | TEXT | 所属词书 ID |
| `user_state` | INTEGER DEFAULT 0 | 学习状态：0=未学, 1=学习中, 2=已掌握, 3=忽略 |
| `next_review_at` | INTEGER | 下次复习时间戳 |
| `last_reviewed_at` | INTEGER | 上次复习时间戳 |
| `first_learned_at` | INTEGER | 首次学习时间戳 |
| `streak` | INTEGER DEFAULT 0 | 连续正确次数 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习次数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败次数 |
| `interval` | INTEGER DEFAULT 0 | 复习间隔 |
| `ease_factor` | REAL DEFAULT 2.5 | SM-2 易度因子 |
| `stability` | REAL DEFAULT 0 | FSRS 稳定性 |
| `difficulty` | REAL DEFAULT 0 | FSRS 难度 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

> UNIQUE (user_id, word_id, book_id)

---

### 2.4 词书与课程 (Books & Lessons)

#### `books` — 词书表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | UUID |
| `title` | TEXT | 书名 |
| `subtitle` | TEXT | 副标题 |
| `description` | TEXT | 描述 |
| `cover_image_key` | TEXT | R2 封面图片路径 |
| `has_lessons` | INTEGER DEFAULT 0 | 是否按课组织 |
| `word_count` | INTEGER DEFAULT 0 | 单词总数 |
| `sort_order` | INTEGER DEFAULT 0 | 排序 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

#### `lessons` — 课程表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | UUID |
| `book_id` | TEXT | 词书 ID → books.id (CASCADE) |
| `lesson_number` | INTEGER | 课程序号 |
| `title` | TEXT | 课程标题 |
| `word_count` | INTEGER DEFAULT 0 | 单词数 |
| `sort_order` | INTEGER DEFAULT 0 | 排序 |
| `created_at` | INTEGER | 创建时间戳 |

> UNIQUE (book_id, lesson_number)

#### `lesson_word_map` — 课程单词关联表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | UUID |
| `book_id` | TEXT | 词书 ID → books.id (CASCADE) |
| `lesson_id` | TEXT | 课程 ID → lessons.id (SET NULL) |
| `word_id` | TEXT | 单词 ID → words.id (CASCADE) |
| `sort_order` | INTEGER DEFAULT 0 | 课内排序 |
| `book_sort_order` | INTEGER DEFAULT 0 | 全书排序（跨课连续递增） |
| `created_at` | INTEGER | 创建时间戳 |

---

### 2.5 学习会话与进度

#### `learning_sessions` — 新词学习会话表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `user_id` | INTEGER | 用户 ID → users.id |
| `book_id` | TEXT | 词书 ID |
| `word_ids` | TEXT (JSON) | JSON 数组，本次会话的单词 ID 列表 |
| `current_index` | INTEGER DEFAULT 0 | 当前进度索引 |
| `batch_start_sort` | INTEGER DEFAULT 0 | 批次起始 book_sort_order |
| `batch_end_sort` | INTEGER DEFAULT 0 | 批次结束 book_sort_order |
| `started_at` | INTEGER | 开始时间戳 |
| `status` | TEXT DEFAULT 'active' | 状态：active/completed |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

> UNIQUE (user_id, book_id, status)

#### `book_progress` — 词书学习进度表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `user_id` | INTEGER | 用户 ID → users.id |
| `book_id` | TEXT | 词书 ID |
| `total_words` | INTEGER DEFAULT 0 | 总单词数 |
| `learned_count` | INTEGER DEFAULT 0 | 已学数量 (user_state=1) |
| `mastered_count` | INTEGER DEFAULT 0 | 已掌握数量 (user_state=2) |
| `ignored_count` | INTEGER DEFAULT 0 | 已忽略数量 (user_state=3) |
| `is_completed` | INTEGER DEFAULT 0 | 是否已完成 |
| `current_sort_cursor` | INTEGER DEFAULT 0 | 当前学习进度游标 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

> UNIQUE (user_id, book_id)

---

### 2.6 语法系统 (Grammar)

#### `grammars` — 语法条目表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `title` | TEXT | 语法标题 |
| `jlpt_level` | TEXT | JLPT 等级 |
| `usage_frequency` | INTEGER DEFAULT 0 | 使用频率 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

#### `grammar_meanings` — 语法释义表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `grammar_id` | INTEGER | 语法 ID → grammars.id |
| `sort_order` | INTEGER DEFAULT 1 | 排序 |
| `definition_cn` | TEXT | 中文定义 |
| `definition_en` | TEXT | 英文定义 |
| `how_to_use_cn` | TEXT | 中文用法说明 |
| `how_to_use_en` | TEXT | 英文用法说明 |

#### `grammar_contexts` — 语法使用场景表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `grammar_id` | INTEGER | 语法 ID → grammars.id |
| `when_to_use_cn` | TEXT | 中文使用时机说明 |
| `when_to_use_en` | TEXT | 英文使用时机说明 |

#### `grammar_examples` — 语法例句表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `grammar_id` | INTEGER | 语法 ID → grammars.id |
| `sort_order` | INTEGER DEFAULT 1 | 排序 |
| `sentence` | TEXT | 日文例句 |
| `translation_cn` | TEXT | 中文翻译 |
| `translation_en` | TEXT | 英文翻译 |
| `audio_url` | TEXT | 音频 URL |

#### `study_grammars` — 用户语法学习状态表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 自增主键 |
| `user_id` | INTEGER | 用户 ID → users.id |
| `grammar_id` | INTEGER | 语法 ID → grammars.id |
| `learning_status` | INTEGER DEFAULT 0 | 学习状态：0=未学, 1=学习中, 2=已掌握, 3=忽略 |
| `next_review_at` | INTEGER | 下次复习时间戳 |
| `last_reviewed_at` | INTEGER | 上次复习时间戳 |
| `streak` | INTEGER DEFAULT 0 | 连续正确次数 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习次数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败次数 |
| `interval` | REAL DEFAULT 0 | 复习间隔 |
| `ease_factor` | REAL DEFAULT 2.5 | SM-2 易度因子 |
| `stability` | REAL DEFAULT 0 | FSRS 稳定性 |
| `difficulty` | REAL DEFAULT 0 | FSRS 难度 |
| `created_at` | INTEGER | 创建时间戳 |
| `updated_at` | INTEGER | 更新时间戳 |

> UNIQUE (user_id, grammar_id)

---

### 2.7 新闻系统 (NHK Articles)

#### `articles` — 新闻元数据表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | NHK 新闻 ID（如 ne2026031311469） |
| `title` | TEXT | 带 ruby 注音标题 |
| `clean_title` | TEXT | 纯净标题（无注音） |
| `published_at` | TEXT | 新闻发布时间 |
| `audio_url` | TEXT | R2 音频访问 URL |
| `duration_ms` | INTEGER DEFAULT 0 | 音频时长（毫秒） |
| `sentence_count` | INTEGER DEFAULT 0 | 句子数量 |
| `is_archived` | INTEGER DEFAULT 0 | 软删除标记 |
| `created_at` | TEXT | 入库时间 |
| `updated_at` | TEXT | 最后更新时间 |

#### `article_details` — 新闻详情表
| 字段 | 类型 | 说明 |
|------|------|------|
| `article_id` | TEXT PK | 新闻 ID → articles.id |
| `items` | TEXT (JSON) | 句子+分词数组。每项含：text(带注音原文), translation(中文翻译), start_ms, end_ms, index, words(Sudachi 分词) |
| `created_at` | TEXT | 创建时间 |
| `updated_at` | TEXT | 更新时间 |

---

### 2.8 同步相关

#### `sync_metadata` — 同步元数据表
| 字段 | 类型 | 说明 |
|------|------|------|
| `key` | TEXT PK | 元数据键（如 articles_last_updated_at, words_version） |
| `value` | TEXT | 元数据值 |
| `updated_at` | INTEGER | 更新时间戳 |

---

## 三、Supabase 云端扩展表结构

> 云端 Supabase 包含上述所有表，并额外包含以下用户数据同步表和系统功能。

### 3.1 用户数据同步系统 (4.0)

#### `user_profiles` — 用户档案表
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID PK | 关联 auth.users(id) (CASCADE) |
| `display_name` | TEXT | 显示名称 |
| `email` | TEXT | 邮箱 |
| `avatar_url` | TEXT | 头像 URL |
| `locale` | TEXT DEFAULT 'zh' | 语言偏好 |
| `timezone` | TEXT | 时区 |
| `settings` | JSONB DEFAULT '{}' | JSON 偏好设置 |
| `onboarding_completed` | BOOLEAN DEFAULT false | 是否完成引导 |
| `pro_status` | SMALLINT DEFAULT 0 | 会员状态 |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 乐观锁版本号 |

#### `user_devices` — 用户设备表
| 字段 | 类型 | 说明 |
|------|------|------|
| `device_id` | UUID PK | 设备 UUID |
| `user_id` | UUID | 用户 ID (CASCADE) |
| `platform` | TEXT | 平台（ios/android/web） |
| `device_name` | TEXT | 设备名称 |
| `app_version` | TEXT | App 版本号 |
| `last_seen_at` | TIMESTAMPTZ | 最后在线时间 |
| `last_push_seq` | BIGINT DEFAULT 0 | 最后推送序号 |
| `last_pull_seq` | BIGINT DEFAULT 0 | 最后拉取序号 |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |

#### `user_word_states` — 用户单词学习状态表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID (CASCADE) |
| `word_id` | TEXT | 单词 ID |
| `book_id` | TEXT | 词书 ID |
| `user_state` | INTEGER CHECK(0,1,2,3) | 学习状态 |
| `next_review_at` | BIGINT | 下次复习时间戳 |
| `last_reviewed_at` | BIGINT | 上次复习时间戳 |
| `first_learned_at` | BIGINT | 首次学习时间戳 |
| `interval` | INTEGER | 复习间隔 |
| `ease_factor` | DOUBLE PRECISION | SM-2 易度因子 |
| `stability` | DOUBLE PRECISION | FSRS 稳定性 |
| `difficulty` | DOUBLE PRECISION | FSRS 难度 |
| `streak` | INTEGER DEFAULT 0 | 连续正确 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败数 |
| `source_device_id` | UUID | 来源设备 |
| `last_mutation_id` | UUID | 最后变更 ID |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 乐观锁版本号 |

> PRIMARY KEY (user_id, word_id, book_id)

#### `user_word_favorites` — 用户单词收藏表
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID |
| `word_id` | TEXT | 单词 ID |
| `book_id` | TEXT | 所属词书 |
| `source_device_id` | UUID | 来源设备 |
| `last_mutation_id` | UUID | 最后变更 ID |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 版本号 |

> PRIMARY KEY (user_id, word_id)

#### `user_word_example_favorites` — 用户例句收藏表
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID |
| `example_id` | TEXT | 例句 ID |
| `word_id` | TEXT | 所属单词 ID |
| `source_device_id` | UUID | 来源设备 |
| `last_mutation_id` | UUID | 最后变更 ID |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 版本号 |

> PRIMARY KEY (user_id, example_id)

#### `user_kana_states` — 用户假名学习状态表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID |
| `kana_id` | INTEGER | 假名 ID |
| `learning_status` | INTEGER CHECK(0,1,2,3) | 学习状态 |
| `next_review_at` | BIGINT | 下次复习时间戳 |
| `last_reviewed_at` | BIGINT | 上次复习时间戳 |
| `streak` | INTEGER DEFAULT 0 | 连续正确 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败数 |
| `interval` | DOUBLE PRECISION DEFAULT 0 | 间隔 |
| `ease_factor` | DOUBLE PRECISION DEFAULT 2.5 | 易度因子 |
| `stability` | DOUBLE PRECISION DEFAULT 0 | 稳定性 |
| `difficulty` | DOUBLE PRECISION DEFAULT 0 | 难度 |
| `source_device_id` | UUID | 来源设备 |
| `last_mutation_id` | UUID | 最后变更 ID |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 版本号 |

> PRIMARY KEY (user_id, kana_id)

#### `user_grammar_states` — 用户语法学习状态表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID |
| `grammar_id` | INTEGER | 语法 ID |
| `learning_status` | INTEGER CHECK(0,1,2,3) | 学习状态 |
| `next_review_at` | BIGINT | 下次复习时间戳 |
| `last_reviewed_at` | BIGINT | 上次复习时间戳 |
| `streak` | INTEGER DEFAULT 0 | 连续正确 |
| `total_reviews` | INTEGER DEFAULT 0 | 总复习数 |
| `fail_count` | INTEGER DEFAULT 0 | 失败数 |
| `interval` | DOUBLE PRECISION DEFAULT 0 | 间隔 |
| `ease_factor` | DOUBLE PRECISION DEFAULT 2.5 | 易度因子 |
| `stability` | DOUBLE PRECISION DEFAULT 0 | 稳定性 |
| `difficulty` | DOUBLE PRECISION DEFAULT 0 | 难度 |
| `source_device_id` | UUID | 来源设备 |
| `last_mutation_id` | UUID | 最后变更 ID |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 版本号 |

> PRIMARY KEY (user_id, grammar_id)

#### `user_book_progress` — 用户词书学习进度表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `user_id` | UUID | 用户 ID |
| `book_id` | TEXT | 词书 ID |
| `total_words` | INTEGER DEFAULT 0 | 总单词数 |
| `learned_count` | INTEGER DEFAULT 0 | 学习中数量 |
| `mastered_count` | INTEGER DEFAULT 0 | 已掌握数量 |
| `ignored_count` | INTEGER DEFAULT 0 | 已忽略数量 |
| `is_completed` | BOOLEAN DEFAULT false | 是否已完成 |
| `current_sort_cursor` | INTEGER DEFAULT 0 | 当前进度游标 |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |
| `version` | BIGINT DEFAULT 1 | 版本号 |

> PRIMARY KEY (user_id, book_id)

#### `user_learning_sessions` — 用户学习会话表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID PK | 会话 UUID |
| `user_id` | UUID | 用户 ID (CASCADE) |
| `device_id` | UUID (nullable) | 设备 ID |
| `book_id` | TEXT | 词书 ID |
| `status` | TEXT CHECK(active,completed,abandoned) | 会话状态 |
| `word_ids` | TEXT[] | 单词 ID 数组 |
| `words_payload` | JSONB DEFAULT '[]' | 完整单词数据快照 |
| `batch_start_sort` | INTEGER | 批次起始 book_sort_order |
| `batch_end_sort` | INTEGER | 批次结束 book_sort_order |
| `completed_at` | TIMESTAMPTZ | 完成时间 |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |

> UNIQUE INDEX (user_id, book_id) WHERE status = 'active'

#### `user_review_sessions` — 用户复习会话表（云端版）
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID PK | 会话 UUID |
| `user_id` | UUID | 用户 ID (CASCADE) |
| `session_kind` | TEXT CHECK(word,kana) | 会话类型：单词/假名 |
| `status` | TEXT CHECK(active,completed,abandoned) | 会话状态 |
| `current_index` | INTEGER DEFAULT 0 | 当前复习进度索引 |
| `items` | JSONB DEFAULT '[]' | 复习题目数据 |
| `closed_at` | TIMESTAMPTZ | 关闭时间 |
| `created_at` | TIMESTAMPTZ | 创建时间 |
| `updated_at` | TIMESTAMPTZ | 自动更新 |

> UNIQUE INDEX (user_id, session_kind) WHERE status = 'active'

---

### 3.2 问题上报系统 (3.0)

#### `issue_reports` — 问题反馈表
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID PK | 反馈 UUID |
| `user_id` | UUID | 上报用户 |
| `content_type` | TEXT CHECK(word,grammar) | 内容类型 |
| `content_id` | TEXT | 内容 ID（word UUID 或 grammar int id） |
| `content_snapshot` | JSONB | 提交时的完整数据快照 |
| `message` | TEXT | 用户描述（可选） |
| `status` | TEXT CHECK(open,resolved,ignored) DEFAULT 'open' | 处理状态 |
| `admin_note` | TEXT | 管理员备注 |
| `resolved_at` | TIMESTAMPTZ | 解决时间 |
| `created_at` | TIMESTAMPTZ | 创建时间 |

> RLS: 用户只能读写自己的上报

---

### 3.3 PostgreSQL 函数 (RPC)

| 函数名 | 用途 |
|--------|------|
| `update_updated_at()` | 触发器函数：自动更新 `updated_at` 字段为 `now()` |
| `sync_rebuild_book_progress(p_user_id, p_book_id, p_payload)` | 重建用户词书进度统计（学习/掌握/忽略数量及完成状态） |
| `complete_word_review_session(p_user_id, p_session_id, p_word_states)` | 完成单词复习会话，upsert 单词状态并关闭会话 |
| `complete_kana_review_session(p_user_id, p_session_id, p_kana_states)` | 完成假名复习会话，upsert 假名状态并关闭会话 |
| `complete_word_learning_session(p_user_id, p_session_id, p_word_states, p_total_words, p_first_review_interval_minutes)` | 完成新词学习会话，upsert 单词状态、设置首次复习时间、更新进度游标 |

---

### 3.4 数据库视图 (Views)

| 视图名 | 用途 |
|--------|------|
| `user_word_book_view` | 将 user_word_states 与 words 表 JOIN，提供单词本所需的完整字段 |
| `user_word_favorite_book_view` | 将 user_word_favorites 与 words 表 JOIN，提供收藏单词本视图 |
| `user_word_example_favorite_view` | 将 user_word_example_favorites、word_examples、words 三表 JOIN |
| `user_grammar_book_view` | 将 user_grammar_states 与 grammars 表 JOIN，提供语法本视图 |

---

## 四、Cloudflare Workers API 接口

> Base URL: `https://<worker-host>/api/v1/`
> 认证方式: Supabase JWT (Bearer Token)
> 数据库代理: 通过 Supabase REST API (`/rest/v1/*`) 读写数据，使用 service_role key

### 4.1 健康检查

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/health` | 无 | 服务健康检查，返回 `{"status":"ok","timestamp":"..."}` |

---

### 4.2 新闻文章 (Articles)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/articles` | JWT 必需 | 获取新闻列表，支持增量同步和分页。查询参数：`since` (ISO8601, 增量过滤), `limit` (默认50, 最大200), `cursor` (分页游标, published_at)。返回带 KV 缓存（5分钟） |
| `GET` | `/articles/:id` | JWT 必需 | 获取单篇新闻详情，含完整句子和 Sudachi 分词数据。返回带 KV 缓存 |

---

### 4.3 词书与单词 (Books & Words)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/books` | 无（公开） | 获取所有可用词书列表（is_available=true），按 sort_order 排序。返回含精确 word_count |
| `GET` | `/books/:bookId/next-words` | 无（公开） | 按 book_sort_order 顺序取下一批新词（含完整详情）。查询参数：`after_sort` (上一词游标，0=从头), `limit` (默认10, 最大50) |
| `GET` | `/words/:id` | 可选 JWT | 获取单个词条的完整详情（含 rich_content + examples）。若已登录则附带收藏状态 |

---

### 4.4 学习会话 (Learn Sessions)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `POST` | `/learn/sessions` | JWT 必需 | 创建新词学习会话。请求体：`{"book_id":"...", "device_id":"...?", "limit":10}`。若已有活跃会话则返回续接。limit 最大 50 |
| `POST` | `/learn/sessions/:sessionId/complete` | JWT 必需 | 完成学习会话。请求体：`{"word_states":[{"word_id":"...","user_state":1}], "first_review_interval_minutes":10}`。调用 RPC `complete_word_learning_session` |

---

### 4.5 复习会话 (Review Sessions)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `POST` | `/review/sessions` | JWT 必需 | 创建复习会话。请求体：`{"kind":"word|kana", "limit":50}`。word 类型含 5 种题型（word→meaning, audio→meaning, kanji→reading, meaning→spelling, cloze_test），kana 类型含 6 种题型。最大 50 题 |
| `POST` | `/review/sessions/:sessionId/complete` | JWT 必需 | 完成复习会话，提交评分结果。请求体：`{"results":[{"word_id":"...","book_id":"...","rating":"again|hard|good|easy"}]}`。调用 RPC 更新状态 |
| `POST` | `/review/sessions/:sessionId/abandon` | JWT 必需 | 放弃当前复习会话，将会话状态设为 abandoned |

---

### 4.6 学习状态同步

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `POST` | `/word/states` | JWT 必需 | Upsert 用户单词学习状态（SM-2/FSRS 参数）。请求体：`{"states":[{"word_id":"...","book_id":"...","user_state":1,...}]}` |
| `POST` | `/kana/states` | JWT 必需 | Upsert 用户假名学习状态。请求体：`{"states":[{"kana_id":1,"learning_status":1,...}]}` 或单个对象 |
| `POST` | `/grammar/states` | JWT 必需 | Upsert 用户语法学习状态。请求体：`{"states":[{"grammar_id":1,"learning_status":1,...}]}` |

---

### 4.7 个人数据查询 (Me)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/me/home-summary` | JWT 必需 | 获取首页摘要：用户名、单词/假名待复习数、已掌握数 |
| `GET` | `/me/word-book` | JWT 必需 | 获取用户单词本（全部学习过的单词列表，含状态） |
| `GET` | `/me/kana-states` | JWT 必需 | 获取用户全部假名学习状态 |
| `GET` | `/me/grammar-book` | JWT 必需 | 获取用户语法本（全部学习过的语法列表） |
| `GET` | `/me/example-favorites` | JWT 必需 | 获取用户收藏的例句列表 |

---

### 4.8 收藏系统 (Favorites)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `POST` | `/favorites/words/toggle` | JWT 必需 | 切换单词收藏状态（无则添加，有则删除）。请求体：`{"word_id":"..."}` |
| `POST` | `/favorites/examples/toggle` | JWT 必需 | 切换例句收藏状态（无则添加，有则删除）。请求体：`{"example_id":"...","word_id":"..."}` |

---

### 4.9 语法查询 (Grammar)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/grammars` | JWT 必需 | 获取语法列表，支持过滤。查询参数：`limit` (默认20, 最大50), `exclude_ids` (逗号分隔排除), `unlearned_only` (仅未学), `jlpt_level` (按 JLPT 等级过滤)。按 usage_frequency DESC 排序 |
| `GET` | `/grammars/:id` | JWT 必需 | 获取单个语法完整详情（含 meanings, contexts, examples, 用户学习状态） |

---

### 4.10 参考内容 (Reference)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/reference` | 无（公开） | 获取日语数字、日期、时间、量词等参考数据（静态 JSON，硬编码在 Worker 中）。包含：numbers（基本数字/百/千/大数）、datesAndMonths（月份/日期）、time（小时/分钟）、counters（通用量词/人/细长物/扁平物/小动物） |

---

### 4.11 音频代理 (Audio)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/audio/:id` | JWT 必需 | 【旧版】新闻音频代理。R2 路径：`audio/audio_articles/{id}.mp3`。支持 Range 请求（HTTP 206），缓存 1 年 |
| `GET` | `/audio/words/:id` | 无（公开） | 单词发音音频代理。R2 路径：`audio/words/{id}/main.mp3`。支持 Range 请求（HTTP 206），缓存 1 年 |

---

### 4.12 问题反馈 (Issues)

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `POST` | `/issues` | JWT 必需 | 提交内容问题反馈。请求体：`{"content_type":"word|grammar","content_id":"...","content_snapshot":{...},"message":"..."}`。写入 issue_reports 表，返回 201 |

---

### 4.13 CORS

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `OPTIONS` | `*` | 无 | CORS 预检请求，返回允许的 Methods/Headers |

---

## 五、数据流概览

```
┌──────────────┐     JWT Auth      ┌──────────────────┐    service_role    ┌──────────────┐
│  Flutter App  │ ────────────────→ │ CloudflareWorker │ ────────────────→ │   Supabase   │
│  (SQLite本地) │ ←──────────────── │   (API 路由)     │ ←──────────────── │  (PostgreSQL)│
└──────────────┘     JSON/HTTP      └──────────────────┘    REST API        └──────────────┘
       │                                    │
       │ 本地离线存储                         │  KV 缓存 (文章列表/详情)
       ▼                                    ▼
┌──────────────┐                    ┌──────────────┐
│  breeze_jp   │                    │  Cloudflare  │
│  .sqlite     │                    │  KV + R2     │
└──────────────┘                    └──────────────┘
```

- **本地 SQLite**：存储完整的假名、单词、语法、词书数据，以及用户学习状态和进度。支持离线使用。
- **Supabase PostgreSQL**：作为单一权威数据源，存储所有内容和用户数据。通过 RLS 确保用户数据隔离。
- **Cloudflare Workers**：作为 API 网关层，承担认证校验、数据聚合（批量查询多表）、R2 音频代理、KV 缓存等职责。所有内容表读操作使用 Supabase REST API，写操作通过 REST 和 RPC 函数完成。
- **KV 缓存**：文章列表和详情缓存，减少 Supabase 请求。
- **R2 存储**：音频文件（文章音频 `audio/audio_articles/{id}.mp3`，单词音频 `audio/words/{id}/main.mp3`）以及词书封面图。
