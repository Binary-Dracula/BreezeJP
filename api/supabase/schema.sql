-- =============================================================
-- BreezeJP Supabase 数据库 Schema
-- 项目: eecfrzvutrhftwvyebpq.supabase.co
-- =============================================================

-- 该文件是当前远端数据库的单一权威 schema，设计为可重复执行。
-- 禁止在主 schema 中保留 destructive reset 语句；如需重建环境，应使用单独的 reset 脚本。

-- --------------------------------------------------
-- 1. 新闻文章元数据表（轻量，用于列表展示）
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS articles (
    id              TEXT        PRIMARY KEY,               -- NHK 新闻 ID, e.g. "ne2026031311469"
    title           TEXT        NOT NULL,                  -- 带 ruby 注音标题 e.g. "イラン[...]"
    clean_title     TEXT        NOT NULL DEFAULT '',       -- 纯净标题（无注音）
    published_at    TIMESTAMPTZ NOT NULL,                  -- 新闻发布时间
    audio_url       TEXT        NOT NULL DEFAULT '',       -- R2 音频访问 URL
    duration_ms     INTEGER     NOT NULL DEFAULT 0,        -- 音频时长（毫秒）
    sentence_count  INTEGER     NOT NULL DEFAULT 0,        -- 句子数量
    is_archived     BOOLEAN     NOT NULL DEFAULT false,    -- 软删除标记（NHK 下线的旧新闻）
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),    -- 入库时间
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()     -- 最后更新时间
);

-- --------------------------------------------------
-- 2. 新闻详情表（完整句子 + 分词数据）
-- --------------------------------------------------
-- items 字段为 JSONB，存储完整的 sentences 数组
-- 每个 item 结构：
-- {
--   "text": "...",          -- 带 ruby 注音的原文
--   "translation": "...",   -- 中文翻译
--   "start_ms": 900,        -- 音频起始时间戳
--   "end_ms": 7740,         -- 音频结束时间戳
--   "index": 0,             -- 句子序号
--   "words": [ ... ]        -- 分词数组（Sudachi 全字段保留）
-- }
CREATE TABLE IF NOT EXISTS article_details (
    article_id  TEXT        PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
    items       JSONB       NOT NULL DEFAULT '[]',         -- 句子+分词数组
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- --------------------------------------------------
-- 3. 同步元数据表（支持客户端增量更新）
-- --------------------------------------------------
-- 存储服务端数据版本信息，客户端据此判断是否有新数据
CREATE TABLE IF NOT EXISTS sync_metadata (
    key         TEXT        PRIMARY KEY,
    value       TEXT        NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 初始化：记录数据最后更新时间
INSERT INTO sync_metadata (key, value)
VALUES ('articles_last_updated_at', '1970-01-01T00:00:00Z')
ON CONFLICT (key) DO NOTHING;

-- --------------------------------------------------
-- 4. 索引
-- --------------------------------------------------
-- 列表查询：按发布时间倒序翻页
CREATE INDEX IF NOT EXISTS idx_articles_published_at
    ON articles (published_at DESC);

-- 增量同步：只拉取 updated_at > since 的文章
CREATE INDEX IF NOT EXISTS idx_articles_updated_at
    ON articles (updated_at DESC);

-- 过滤已归档文章
CREATE INDEX IF NOT EXISTS idx_articles_is_archived
    ON articles (is_archived)
    WHERE is_archived = false;

-- --------------------------------------------------
-- 5. 自动更新 updated_at 的触发器
-- --------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_articles_updated_at ON articles;
CREATE TRIGGER trg_articles_updated_at
    BEFORE UPDATE ON articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_article_details_updated_at ON article_details;
CREATE TRIGGER trg_article_details_updated_at
    BEFORE UPDATE ON article_details
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- --------------------------------------------------
-- 6. Row Level Security (RLS)
-- --------------------------------------------------
-- 启用 RLS：所有表默认拒绝访问
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- articles：任何已登录用户（含匿名用户）可读
DROP POLICY IF EXISTS "authenticated users can read articles" ON articles;
CREATE POLICY "authenticated users can read articles"
    ON articles FOR SELECT
    TO authenticated
    USING (true);

-- article_details：任何已登录用户可读
DROP POLICY IF EXISTS "authenticated users can read article_details" ON article_details;
CREATE POLICY "authenticated users can read article_details"
    ON article_details FOR SELECT
    TO authenticated
    USING (true);

-- sync_metadata：任何已登录用户可读
DROP POLICY IF EXISTS "authenticated users can read sync_metadata" ON sync_metadata;
CREATE POLICY "authenticated users can read sync_metadata"
    ON sync_metadata FOR SELECT
    TO authenticated
    USING (true);

-- 注意：写入（INSERT/UPDATE）只允许 service_role（即 CF Workers 服务端）
-- service_role 自动绕过 RLS，无需额外策略

-- =============================================================
-- 2.0 单词系统表 (words, word_details, word_examples, books, lessons)
-- =============================================================

-- --------------------------------------------------
-- 1. 单词主表（轻量索引字段，用于列表/搜索）
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS words (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word TEXT NOT NULL,                    -- 目标单词（如：気[き]づく）
    reading TEXT NOT NULL,                 -- 假名读音（如：きづく）
    romaji TEXT,                           -- 罗马音
    pitch_accent TEXT,                     -- 声调
    jlpt_level TEXT,                       -- JLPT 等级
    part_of_speech TEXT NOT NULL,          -- 词性
    transitivity TEXT,                     -- 自動詞/他動詞/null
    primary_meaning TEXT,                  -- 首要中文释义（列表展示用）
    has_audio BOOLEAN DEFAULT false,       -- 是否有音频
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_words_word ON words(word);
CREATE INDEX IF NOT EXISTS idx_words_reading ON words(reading);
CREATE INDEX IF NOT EXISTS idx_words_jlpt ON words(jlpt_level);
CREATE INDEX IF NOT EXISTS idx_words_updated_at ON words(updated_at);

-- 约束语义：任何影响词条展示内容或书内顺序的改动都必须 bump words.updated_at
-- 触发器已保证 UPDATE 时自动刷新；上传脚本和手动修改时同样须遵守

-- 自动更新触发器
DROP TRIGGER IF EXISTS trg_words_updated_at ON words;
CREATE TRIGGER trg_words_updated_at
    BEFORE UPDATE ON words
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- --------------------------------------------------
-- 2. 深度内容表（纯文本 7 维度 JSONB，入库保留 _source_meta，API 层脱敏）
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS word_details (
    word_id UUID PRIMARY KEY REFERENCES words(id) ON DELETE CASCADE,
    rich_content JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 自动更新触发器
DROP TRIGGER IF EXISTS trg_word_details_updated_at ON word_details;
CREATE TRIGGER trg_word_details_updated_at
    BEFORE UPDATE ON word_details
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- --------------------------------------------------
-- 3. 例句表（独立建表，有关联音频）
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS word_examples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    japanese TEXT NOT NULL,                -- 日文例句（含 ruby）
    chinese TEXT NOT NULL,                 -- 中文翻译
    has_audio BOOLEAN DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_word_examples_word_id ON word_examples(word_id);

-- --------------------------------------------------
-- 4. 书体系与课表
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,                   -- 书名
    subtitle TEXT,
    description TEXT,
    cover_image_key TEXT,                  -- R2 封面图路径
    is_available BOOLEAN NOT NULL DEFAULT true,
    has_lessons BOOLEAN DEFAULT false,     -- 是否按课组织
    word_count INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE books
    ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT true;

DROP TRIGGER IF EXISTS trg_books_updated_at ON books;
CREATE TRIGGER trg_books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX IF NOT EXISTS idx_books_available_sort
    ON books (is_available, sort_order);

CREATE TABLE IF NOT EXISTS lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    lesson_number INTEGER NOT NULL,
    title TEXT,
    word_count INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_lessons_book_num ON lessons(book_id, lesson_number);

-- 课-单词关联表
CREATE TABLE IF NOT EXISTS lesson_word_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES lessons(id) ON DELETE SET NULL,
    word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,        -- 课内排序
    book_sort_order INTEGER NOT NULL DEFAULT 0,   -- 全书排序（跨课连续递增，用于客户端顺序取词）
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lwm_book ON lesson_word_map(book_id);
CREATE INDEX IF NOT EXISTS idx_lwm_lesson ON lesson_word_map(lesson_id);
CREATE INDEX IF NOT EXISTS idx_lwm_word ON lesson_word_map(word_id);
CREATE INDEX IF NOT EXISTS idx_lwm_book_sort ON lesson_word_map(book_id, book_sort_order);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lwm_unique ON lesson_word_map(book_id, COALESCE(lesson_id, '00000000-0000-0000-0000-000000000000'), word_id);

-- --------------------------------------------------
-- 5. 语法内容表
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS grammars (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    jlpt_level TEXT,
    usage_frequency INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_grammars_updated_at ON grammars;
CREATE TRIGGER trg_grammars_updated_at
    BEFORE UPDATE ON grammars
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX IF NOT EXISTS idx_grammars_jlpt ON grammars(jlpt_level);
CREATE INDEX IF NOT EXISTS idx_grammars_usage_frequency ON grammars(usage_frequency DESC);

CREATE TABLE IF NOT EXISTS grammar_meanings (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    grammar_id INTEGER NOT NULL REFERENCES grammars(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 1,
    definition_cn TEXT,
    definition_en TEXT,
    how_to_use_cn TEXT,
    how_to_use_en TEXT
);

CREATE INDEX IF NOT EXISTS idx_grammar_meanings_grammar_sort
    ON grammar_meanings(grammar_id, sort_order);

CREATE TABLE IF NOT EXISTS grammar_contexts (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    grammar_id INTEGER NOT NULL REFERENCES grammars(id) ON DELETE CASCADE,
    when_to_use_cn TEXT,
    when_to_use_en TEXT
);

CREATE INDEX IF NOT EXISTS idx_grammar_contexts_grammar
    ON grammar_contexts(grammar_id);

CREATE TABLE IF NOT EXISTS grammar_examples (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    grammar_id INTEGER NOT NULL REFERENCES grammars(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 1,
    sentence TEXT,
    translation_cn TEXT,
    translation_en TEXT,
    audio_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_grammar_examples_grammar_sort
    ON grammar_examples(grammar_id, sort_order);

-- --------------------------------------------------
-- 6. 已下线的远端 Kana 内容表清理
-- --------------------------------------------------
DROP TABLE IF EXISTS kana_stroke_order;
DROP TABLE IF EXISTS kana_examples;
DROP TABLE IF EXISTS kana_letters;
DROP TABLE IF EXISTS kana_audio;

-- --------------------------------------------------
-- 7. Row Level Security (RLS) policies 扩展
-- --------------------------------------------------
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_examples ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_word_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammars ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_meanings ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_contexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE grammar_examples ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated users can read words" ON words;
CREATE POLICY "authenticated users can read words" ON words FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read word_details" ON word_details;
CREATE POLICY "authenticated users can read word_details" ON word_details FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read word_examples" ON word_examples;
CREATE POLICY "authenticated users can read word_examples" ON word_examples FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read books" ON books;
CREATE POLICY "authenticated users can read books" ON books FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read lessons" ON lessons;
CREATE POLICY "authenticated users can read lessons" ON lessons FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read lesson_word_map" ON lesson_word_map;
CREATE POLICY "authenticated users can read lesson_word_map" ON lesson_word_map FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read grammars" ON grammars;
CREATE POLICY "authenticated users can read grammars" ON grammars FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read grammar_meanings" ON grammar_meanings;
CREATE POLICY "authenticated users can read grammar_meanings" ON grammar_meanings FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read grammar_contexts" ON grammar_contexts;
CREATE POLICY "authenticated users can read grammar_contexts" ON grammar_contexts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "authenticated users can read grammar_examples" ON grammar_examples;
CREATE POLICY "authenticated users can read grammar_examples" ON grammar_examples FOR SELECT TO authenticated USING (true);

-- 注册 sync_metadata 标记
INSERT INTO sync_metadata (key, value)
VALUES ('words_version', '2026040601')
ON CONFLICT (key) DO NOTHING;

-- =============================================================
-- 3.0 Issue Report 系统
-- =============================================================

-- --------------------------------------------------
-- 1. 问题上报表
-- --------------------------------------------------
CREATE TABLE IF NOT EXISTS issue_reports (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL,                    -- 上报用户（匿名用户也有 UUID）
    content_type      TEXT NOT NULL CHECK (content_type IN ('word', 'grammar')),
    content_id        TEXT NOT NULL,                    -- word UUID 或 grammar int id
    content_snapshot  JSONB NOT NULL,                   -- 提交时的完整数据快照（只读对比用）
    message           TEXT,                             -- 用户描述（可留空）
    status            TEXT NOT NULL DEFAULT 'open'
                      CHECK (status IN ('open', 'resolved', 'ignored')),
    admin_note        TEXT,                             -- 管理员处理备注
    resolved_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_issue_reports_status ON issue_reports(status);
CREATE INDEX IF NOT EXISTS idx_issue_reports_created ON issue_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_issue_reports_content ON issue_reports(content_type, content_id);

-- RLS
ALTER TABLE issue_reports ENABLE ROW LEVEL SECURITY;

-- 已登录用户可以插入自己的上报
DROP POLICY IF EXISTS "authenticated users can insert own issues" ON issue_reports;
CREATE POLICY "authenticated users can insert own issues"
    ON issue_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 已登录用户可以读取自己的上报
DROP POLICY IF EXISTS "authenticated users can read own issues" ON issue_reports;
CREATE POLICY "authenticated users can read own issues"
    ON issue_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 注意：管理后台使用 service_role 绕过 RLS 进行全量读写

-- --------------------------------------------------
-- 4.0 用户数据同步系统
-- --------------------------------------------------

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id               UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name          TEXT,
    email                 TEXT,
    avatar_url            TEXT,
    locale                TEXT NOT NULL DEFAULT 'zh',
    timezone              TEXT,
    settings              JSONB NOT NULL DEFAULT '{}'::JSONB,
    onboarding_completed  BOOLEAN NOT NULL DEFAULT false,
    pro_status            SMALLINT NOT NULL DEFAULT 0,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    version               BIGINT NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE IF NOT EXISTS user_devices (
    device_id       UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform        TEXT NOT NULL,
    device_name     TEXT,
    app_version     TEXT,
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_push_seq   BIGINT NOT NULL DEFAULT 0,
    last_pull_seq   BIGINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_updated
    ON user_devices(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS user_word_states (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    word_id           TEXT NOT NULL,
    book_id           TEXT NOT NULL,
    user_state        INTEGER NOT NULL CHECK (user_state IN (0, 1, 2, 3)),
    next_review_at    BIGINT,
    last_reviewed_at  BIGINT,
    first_learned_at  BIGINT,
    interval          INTEGER,
    ease_factor       DOUBLE PRECISION,
    stability         DOUBLE PRECISION,
    difficulty        DOUBLE PRECISION,
    streak            INTEGER NOT NULL DEFAULT 0,
    total_reviews     INTEGER NOT NULL DEFAULT 0,
    fail_count        INTEGER NOT NULL DEFAULT 0,
    source_device_id  UUID,
    last_mutation_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    version           BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, word_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_user_word_states_user_updated
    ON user_word_states(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_word_states_user_book
    ON user_word_states(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_user_word_states_user_next_review
    ON user_word_states(user_id, next_review_at);

CREATE TABLE IF NOT EXISTS user_word_favorites (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    word_id           TEXT NOT NULL,
    book_id           TEXT NOT NULL,
    source_device_id  UUID,
    last_mutation_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    version           BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, word_id)
);

CREATE INDEX IF NOT EXISTS idx_user_word_favorites_user_updated
    ON user_word_favorites(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_word_favorites_user_book
    ON user_word_favorites(user_id, book_id);

CREATE TABLE IF NOT EXISTS user_word_example_favorites (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    example_id        TEXT NOT NULL,
    word_id           TEXT NOT NULL,
    source_device_id  UUID,
    last_mutation_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    version           BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, example_id)
);

CREATE INDEX IF NOT EXISTS idx_user_word_example_favorites_user_updated
    ON user_word_example_favorites(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_word_example_favorites_user_word
    ON user_word_example_favorites(user_id, word_id);

CREATE TABLE IF NOT EXISTS user_kana_states (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kana_id           INTEGER NOT NULL,
    learning_status   INTEGER NOT NULL CHECK (learning_status IN (0, 1, 2, 3)),
    next_review_at    BIGINT,
    last_reviewed_at  BIGINT,
    streak            INTEGER NOT NULL DEFAULT 0,
    total_reviews     INTEGER NOT NULL DEFAULT 0,
    fail_count        INTEGER NOT NULL DEFAULT 0,
    interval          DOUBLE PRECISION NOT NULL DEFAULT 0,
    ease_factor       DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    stability         DOUBLE PRECISION NOT NULL DEFAULT 0,
    difficulty        DOUBLE PRECISION NOT NULL DEFAULT 0,
    source_device_id  UUID,
    last_mutation_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    version           BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, kana_id)
);

CREATE INDEX IF NOT EXISTS idx_user_kana_states_user_updated
    ON user_kana_states(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_kana_states_user_next_review
    ON user_kana_states(user_id, next_review_at);

CREATE TABLE IF NOT EXISTS user_grammar_states (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    grammar_id        INTEGER NOT NULL,
    learning_status   INTEGER NOT NULL CHECK (learning_status IN (0, 1, 2, 3)),
    next_review_at    BIGINT,
    last_reviewed_at  BIGINT,
    streak            INTEGER NOT NULL DEFAULT 0,
    total_reviews     INTEGER NOT NULL DEFAULT 0,
    fail_count        INTEGER NOT NULL DEFAULT 0,
    interval          DOUBLE PRECISION NOT NULL DEFAULT 0,
    ease_factor       DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    stability         DOUBLE PRECISION NOT NULL DEFAULT 0,
    difficulty        DOUBLE PRECISION NOT NULL DEFAULT 0,
    source_device_id  UUID,
    last_mutation_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    version           BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, grammar_id)
);

CREATE INDEX IF NOT EXISTS idx_user_grammar_states_user_updated
    ON user_grammar_states(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_grammar_states_user_next_review
    ON user_grammar_states(user_id, next_review_at);

CREATE TABLE IF NOT EXISTS user_book_progress (
    user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    book_id               TEXT NOT NULL,
    total_words           INTEGER NOT NULL DEFAULT 0,
    learned_count         INTEGER NOT NULL DEFAULT 0,
    mastered_count        INTEGER NOT NULL DEFAULT 0,
    ignored_count         INTEGER NOT NULL DEFAULT 0,
    is_completed          BOOLEAN NOT NULL DEFAULT false,
    current_sort_cursor   INTEGER NOT NULL DEFAULT 0,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    version               BIGINT NOT NULL DEFAULT 1 CHECK (version > 0),
    PRIMARY KEY (user_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_user_book_progress_user_updated
    ON user_book_progress(user_id, updated_at DESC);

CREATE OR REPLACE VIEW user_word_book_view AS
SELECT
        s.user_id,
        0::BIGINT AS study_word_id,
        s.word_id,
        s.book_id,
        w.word,
        w.reading,
        w.romaji,
        w.jlpt_level,
        w.part_of_speech,
        w.primary_meaning,
        w.has_audio,
        s.user_state,
        EXTRACT(EPOCH FROM s.updated_at)::BIGINT AS updated_at
FROM user_word_states AS s
JOIN words AS w
    ON w.id::TEXT = s.word_id;

CREATE OR REPLACE VIEW user_word_favorite_book_view AS
SELECT
        f.user_id,
        0::BIGINT AS study_word_id,
        f.word_id,
        f.book_id,
        w.word,
        w.reading,
        w.romaji,
        w.jlpt_level,
        w.part_of_speech,
        w.primary_meaning,
        w.has_audio,
        0::INTEGER AS user_state,
        EXTRACT(EPOCH FROM f.updated_at)::BIGINT AS updated_at
FROM user_word_favorites AS f
JOIN words AS w
    ON w.id::TEXT = f.word_id;

CREATE OR REPLACE VIEW user_word_example_favorite_view AS
SELECT
        f.user_id,
        f.example_id,
        f.word_id,
        w.word,
        w.reading,
        w.jlpt_level,
        w.part_of_speech,
        w.primary_meaning,
        e.japanese,
        e.chinese,
        e.has_audio,
        EXTRACT(EPOCH FROM f.updated_at)::BIGINT AS updated_at
FROM user_word_example_favorites AS f
JOIN word_examples AS e
    ON e.id::TEXT = f.example_id
JOIN words AS w
    ON w.id::TEXT = f.word_id;

CREATE OR REPLACE VIEW user_grammar_book_view AS
SELECT
        s.user_id,
        0::BIGINT AS study_grammar_id,
        s.grammar_id,
        g.title,
        g.jlpt_level,
        s.learning_status,
        EXTRACT(EPOCH FROM s.updated_at)::BIGINT AS updated_at
FROM user_grammar_states AS s
JOIN grammars AS g
    ON g.id = s.grammar_id;

CREATE TABLE IF NOT EXISTS sync_mutation_receipts (
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         UUID NOT NULL REFERENCES user_devices(device_id) ON DELETE CASCADE,
    mutation_id       UUID NOT NULL,
    entity_type       TEXT NOT NULL,
    entity_key        TEXT NOT NULL,
    base_version      BIGINT,
    result_version    BIGINT,
    status            TEXT NOT NULL CHECK (status IN ('applied', 'noop', 'duplicate', 'conflict')),
    response_payload  JSONB NOT NULL DEFAULT '{}'::JSONB,
    committed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, device_id, mutation_id)
);

CREATE INDEX IF NOT EXISTS idx_sync_mutation_receipts_user_committed
    ON sync_mutation_receipts(user_id, committed_at DESC);

CREATE TABLE IF NOT EXISTS user_sync_events (
    seq           BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id     UUID NOT NULL REFERENCES user_devices(device_id) ON DELETE CASCADE,
    entity_type   TEXT NOT NULL,
    entity_key    TEXT NOT NULL,
    operation     TEXT NOT NULL,
    payload       JSONB NOT NULL DEFAULT '{}'::JSONB,
    committed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_sync_events_user_seq
    ON user_sync_events(user_id, seq);
CREATE INDEX IF NOT EXISTS idx_user_sync_events_user_committed
    ON user_sync_events(user_id, committed_at DESC);

DROP TRIGGER IF EXISTS trg_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_devices_updated_at ON user_devices;
CREATE TRIGGER trg_user_devices_updated_at
    BEFORE UPDATE ON user_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_word_states_updated_at ON user_word_states;
CREATE TRIGGER trg_user_word_states_updated_at
    BEFORE UPDATE ON user_word_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_word_favorites_updated_at ON user_word_favorites;
CREATE TRIGGER trg_user_word_favorites_updated_at
    BEFORE UPDATE ON user_word_favorites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_word_example_favorites_updated_at ON user_word_example_favorites;
CREATE TRIGGER trg_user_word_example_favorites_updated_at
    BEFORE UPDATE ON user_word_example_favorites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_kana_states_updated_at ON user_kana_states;
CREATE TRIGGER trg_user_kana_states_updated_at
    BEFORE UPDATE ON user_kana_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_grammar_states_updated_at ON user_grammar_states;
CREATE TRIGGER trg_user_grammar_states_updated_at
    BEFORE UPDATE ON user_grammar_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_book_progress_updated_at ON user_book_progress;
CREATE TRIGGER trg_user_book_progress_updated_at
    BEFORE UPDATE ON user_book_progress
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_example_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_kana_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_grammar_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_book_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_mutation_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sync_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated users can read own profile" ON user_profiles;
CREATE POLICY "authenticated users can read own profile"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can upsert own profile" ON user_profiles;
CREATE POLICY "authenticated users can upsert own profile"
    ON user_profiles FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own devices" ON user_devices;
CREATE POLICY "authenticated users can read own devices"
    ON user_devices FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own devices" ON user_devices;
CREATE POLICY "authenticated users can manage own devices"
    ON user_devices FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own word states" ON user_word_states;
CREATE POLICY "authenticated users can read own word states"
    ON user_word_states FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own word states" ON user_word_states;
CREATE POLICY "authenticated users can manage own word states"
    ON user_word_states FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own word favorites" ON user_word_favorites;
CREATE POLICY "authenticated users can read own word favorites"
    ON user_word_favorites FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own word favorites" ON user_word_favorites;
CREATE POLICY "authenticated users can manage own word favorites"
    ON user_word_favorites FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own word example favorites" ON user_word_example_favorites;
CREATE POLICY "authenticated users can read own word example favorites"
    ON user_word_example_favorites FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own word example favorites" ON user_word_example_favorites;
CREATE POLICY "authenticated users can manage own word example favorites"
    ON user_word_example_favorites FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own kana states" ON user_kana_states;
CREATE POLICY "authenticated users can read own kana states"
    ON user_kana_states FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own kana states" ON user_kana_states;
CREATE POLICY "authenticated users can manage own kana states"
    ON user_kana_states FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own grammar states" ON user_grammar_states;
CREATE POLICY "authenticated users can read own grammar states"
    ON user_grammar_states FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own grammar states" ON user_grammar_states;
CREATE POLICY "authenticated users can manage own grammar states"
    ON user_grammar_states FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own book progress" ON user_book_progress;
CREATE POLICY "authenticated users can read own book progress"
    ON user_book_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own mutation receipts" ON sync_mutation_receipts;
CREATE POLICY "authenticated users can read own mutation receipts"
    ON sync_mutation_receipts FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can read own sync events" ON user_sync_events;
CREATE POLICY "authenticated users can read own sync events"
    ON user_sync_events FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION sync_assert_device(
    p_user_id UUID,
    p_device_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM user_devices
        WHERE user_id = p_user_id
          AND device_id = p_device_id
    ) THEN
        RAISE EXCEPTION 'SYNC_DEVICE_NOT_FOUND';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_rebuild_book_progress(
    p_user_id UUID,
    p_book_id TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB
) RETURNS VOID AS $$
DECLARE
    v_learning_count INTEGER := 0;
    v_mastered_count INTEGER := 0;
    v_ignored_count INTEGER := 0;
    v_existing_total_words INTEGER := 0;
    v_existing_cursor INTEGER := 0;
    v_total_words INTEGER := 0;
    v_cursor INTEGER := 0;
BEGIN
    IF p_book_id IS NULL OR btrim(p_book_id) = '' THEN
        RETURN;
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE user_state = 1),
        COUNT(*) FILTER (WHERE user_state = 2),
        COUNT(*) FILTER (WHERE user_state = 3)
    INTO v_learning_count, v_mastered_count, v_ignored_count
    FROM user_word_states
    WHERE user_id = p_user_id
      AND book_id = p_book_id;

    SELECT total_words, current_sort_cursor
    INTO v_existing_total_words, v_existing_cursor
    FROM user_book_progress
    WHERE user_id = p_user_id
      AND book_id = p_book_id;

    v_total_words := COALESCE((p_payload ->> 'total_words')::INTEGER, v_existing_total_words, 0);
    v_cursor := GREATEST(
        COALESCE((p_payload ->> 'current_sort_cursor')::INTEGER, 0),
        COALESCE(v_existing_cursor, 0)
    );

    INSERT INTO user_book_progress (
        user_id,
        book_id,
        total_words,
        learned_count,
        mastered_count,
        ignored_count,
        is_completed,
        current_sort_cursor,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        p_book_id,
        v_total_words,
        v_learning_count,
        v_mastered_count,
        v_ignored_count,
        CASE
            WHEN v_total_words <= 0 THEN false
            ELSE (v_learning_count + v_mastered_count + v_ignored_count) >= v_total_words
        END,
        v_cursor,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, book_id) DO UPDATE SET
        total_words = EXCLUDED.total_words,
        learned_count = EXCLUDED.learned_count,
        mastered_count = EXCLUDED.mastered_count,
        ignored_count = EXCLUDED.ignored_count,
        is_completed = EXCLUDED.is_completed,
        current_sort_cursor = GREATEST(user_book_progress.current_sort_cursor, EXCLUDED.current_sort_cursor),
        updated_at = now(),
        version = user_book_progress.version + 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_profile_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    SELECT version INTO v_current_version
    FROM user_profiles
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(p) INTO v_state
        FROM user_profiles AS p
        WHERE user_id = p_user_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        RETURN jsonb_build_object(
            'status', 'noop',
            'result_version', COALESCE(v_current_version, 0),
            'server_state', NULL,
            'event_payload', NULL
        );
    END IF;

    INSERT INTO user_profiles (
        user_id,
        display_name,
        email,
        avatar_url,
        locale,
        timezone,
        settings,
        onboarding_completed,
        pro_status,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        p_payload ->> 'display_name',
        p_payload ->> 'email',
        p_payload ->> 'avatar_url',
        COALESCE(p_payload ->> 'locale', 'zh'),
        p_payload ->> 'timezone',
        COALESCE(p_payload -> 'settings', '{}'::JSONB),
        COALESCE((p_payload ->> 'onboarding_completed')::BOOLEAN, false),
        COALESCE((p_payload ->> 'pro_status')::SMALLINT, 0),
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id) DO UPDATE SET
        display_name = COALESCE(p_payload ->> 'display_name', user_profiles.display_name),
        email = COALESCE(p_payload ->> 'email', user_profiles.email),
        avatar_url = COALESCE(p_payload ->> 'avatar_url', user_profiles.avatar_url),
        locale = COALESCE(p_payload ->> 'locale', user_profiles.locale),
        timezone = COALESCE(p_payload ->> 'timezone', user_profiles.timezone),
        settings = COALESCE(p_payload -> 'settings', user_profiles.settings),
        onboarding_completed = COALESCE((p_payload ->> 'onboarding_completed')::BOOLEAN, user_profiles.onboarding_completed),
        pro_status = COALESCE((p_payload ->> 'pro_status')::SMALLINT, user_profiles.pro_status),
        updated_at = now(),
        version = user_profiles.version + 1
    RETURNING version INTO v_result_version;

    SELECT to_jsonb(p) INTO v_state
    FROM user_profiles AS p
    WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_word_state_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_word_id TEXT := COALESCE(p_payload ->> 'word_id', '');
    v_book_id TEXT := COALESCE(p_payload ->> 'book_id', '');
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_word_id = '' OR v_book_id = '' THEN
        RAISE EXCEPTION 'SYNC_WORD_STATE_REQUIRES_WORD_AND_BOOK';
    END IF;

    SELECT version INTO v_current_version
    FROM user_word_states
    WHERE user_id = p_user_id
      AND word_id = v_word_id
      AND book_id = v_book_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(s) INTO v_state
        FROM user_word_states AS s
        WHERE user_id = p_user_id
          AND word_id = v_word_id
          AND book_id = v_book_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_word_states
        WHERE user_id = p_user_id
          AND word_id = v_word_id
          AND book_id = v_book_id;

        PERFORM sync_rebuild_book_progress(p_user_id, v_book_id, p_payload);

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'word_id', v_word_id,
                'book_id', v_book_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    IF v_current_version IS NULL AND p_base_version IS NOT NULL AND p_base_version > 0 THEN
        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'MISSING_SERVER_ROW',
            'server_version', NULL,
            'server_state', NULL
        );
    END IF;

    INSERT INTO user_word_states (
        user_id,
        word_id,
        book_id,
        user_state,
        next_review_at,
        last_reviewed_at,
        first_learned_at,
        interval,
        ease_factor,
        stability,
        difficulty,
        streak,
        total_reviews,
        fail_count,
        source_device_id,
        last_mutation_id,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        v_word_id,
        v_book_id,
        COALESCE((p_payload ->> 'user_state')::INTEGER, 0),
        (p_payload ->> 'next_review_at')::BIGINT,
        (p_payload ->> 'last_reviewed_at')::BIGINT,
        (p_payload ->> 'first_learned_at')::BIGINT,
        (p_payload ->> 'interval')::INTEGER,
        (p_payload ->> 'ease_factor')::DOUBLE PRECISION,
        (p_payload ->> 'stability')::DOUBLE PRECISION,
        (p_payload ->> 'difficulty')::DOUBLE PRECISION,
        COALESCE((p_payload ->> 'streak')::INTEGER, 0),
        COALESCE((p_payload ->> 'total_reviews')::INTEGER, 0),
        COALESCE((p_payload ->> 'fail_count')::INTEGER, 0),
        p_device_id,
        p_mutation_id,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, word_id, book_id) DO UPDATE SET
        user_state = COALESCE((p_payload ->> 'user_state')::INTEGER, user_word_states.user_state),
        next_review_at = CASE WHEN p_payload ? 'next_review_at' THEN (p_payload ->> 'next_review_at')::BIGINT ELSE user_word_states.next_review_at END,
        last_reviewed_at = CASE WHEN p_payload ? 'last_reviewed_at' THEN (p_payload ->> 'last_reviewed_at')::BIGINT ELSE user_word_states.last_reviewed_at END,
        first_learned_at = CASE WHEN p_payload ? 'first_learned_at' THEN (p_payload ->> 'first_learned_at')::BIGINT ELSE user_word_states.first_learned_at END,
        interval = CASE WHEN p_payload ? 'interval' THEN (p_payload ->> 'interval')::INTEGER ELSE user_word_states.interval END,
        ease_factor = CASE WHEN p_payload ? 'ease_factor' THEN (p_payload ->> 'ease_factor')::DOUBLE PRECISION ELSE user_word_states.ease_factor END,
        stability = CASE WHEN p_payload ? 'stability' THEN (p_payload ->> 'stability')::DOUBLE PRECISION ELSE user_word_states.stability END,
        difficulty = CASE WHEN p_payload ? 'difficulty' THEN (p_payload ->> 'difficulty')::DOUBLE PRECISION ELSE user_word_states.difficulty END,
        streak = COALESCE((p_payload ->> 'streak')::INTEGER, user_word_states.streak),
        total_reviews = COALESCE((p_payload ->> 'total_reviews')::INTEGER, user_word_states.total_reviews),
        fail_count = COALESCE((p_payload ->> 'fail_count')::INTEGER, user_word_states.fail_count),
        source_device_id = p_device_id,
        last_mutation_id = p_mutation_id,
        updated_at = now(),
        version = user_word_states.version + 1
    RETURNING version INTO v_result_version;

    PERFORM sync_rebuild_book_progress(p_user_id, v_book_id, p_payload);

    SELECT to_jsonb(s) INTO v_state
    FROM user_word_states AS s
    WHERE user_id = p_user_id
      AND word_id = v_word_id
      AND book_id = v_book_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_word_favorite_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_word_id TEXT := COALESCE(p_payload ->> 'word_id', '');
    v_book_id TEXT := COALESCE(p_payload ->> 'book_id', '');
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_word_id = '' THEN
        RAISE EXCEPTION 'SYNC_WORD_FAVORITE_REQUIRES_WORD_ID';
    END IF;

    IF p_operation <> 'delete' AND v_book_id = '' THEN
        RAISE EXCEPTION 'SYNC_WORD_FAVORITE_REQUIRES_BOOK_ID';
    END IF;

    SELECT version INTO v_current_version
    FROM user_word_favorites
    WHERE user_id = p_user_id
      AND word_id = v_word_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(f) INTO v_state
        FROM user_word_favorites AS f
        WHERE user_id = p_user_id
          AND word_id = v_word_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_word_favorites
        WHERE user_id = p_user_id
          AND word_id = v_word_id;

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'word_id', v_word_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    IF v_current_version IS NULL AND p_base_version IS NOT NULL AND p_base_version > 0 THEN
        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'MISSING_SERVER_ROW',
            'server_version', NULL,
            'server_state', NULL
        );
    END IF;

    INSERT INTO user_word_favorites (
        user_id,
        word_id,
        book_id,
        source_device_id,
        last_mutation_id,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        v_word_id,
        v_book_id,
        p_device_id,
        p_mutation_id,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, word_id) DO UPDATE SET
        book_id = COALESCE(NULLIF(p_payload ->> 'book_id', ''), user_word_favorites.book_id),
        source_device_id = p_device_id,
        last_mutation_id = p_mutation_id,
        updated_at = now(),
        version = user_word_favorites.version + 1
    RETURNING version INTO v_result_version;

    SELECT to_jsonb(f) INTO v_state
    FROM user_word_favorites AS f
    WHERE user_id = p_user_id
      AND word_id = v_word_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_word_example_favorite_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_example_id TEXT := COALESCE(p_payload ->> 'example_id', '');
    v_word_id TEXT := COALESCE(p_payload ->> 'word_id', '');
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_example_id = '' OR v_word_id = '' THEN
        RAISE EXCEPTION 'SYNC_WORD_EXAMPLE_FAVORITE_REQUIRES_EXAMPLE_AND_WORD';
    END IF;

    SELECT version INTO v_current_version
    FROM user_word_example_favorites
    WHERE user_id = p_user_id
      AND example_id = v_example_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(f) INTO v_state
        FROM user_word_example_favorites AS f
        WHERE user_id = p_user_id
          AND example_id = v_example_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_word_example_favorites
        WHERE user_id = p_user_id
          AND example_id = v_example_id;

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'example_id', v_example_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    IF v_current_version IS NULL AND p_base_version IS NOT NULL AND p_base_version > 0 THEN
        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'MISSING_SERVER_ROW',
            'server_version', NULL,
            'server_state', NULL
        );
    END IF;

    INSERT INTO user_word_example_favorites (
        user_id,
        example_id,
        word_id,
        source_device_id,
        last_mutation_id,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        v_example_id,
        v_word_id,
        p_device_id,
        p_mutation_id,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, example_id) DO UPDATE SET
        word_id = COALESCE(NULLIF(p_payload ->> 'word_id', ''), user_word_example_favorites.word_id),
        source_device_id = p_device_id,
        last_mutation_id = p_mutation_id,
        updated_at = now(),
        version = user_word_example_favorites.version + 1
    RETURNING version INTO v_result_version;

    SELECT to_jsonb(f) INTO v_state
    FROM user_word_example_favorites AS f
    WHERE user_id = p_user_id
      AND example_id = v_example_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_kana_state_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_kana_id INTEGER := COALESCE((p_payload ->> 'kana_id')::INTEGER, 0);
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_kana_id <= 0 THEN
        RAISE EXCEPTION 'SYNC_KANA_STATE_REQUIRES_KANA_ID';
    END IF;

    SELECT version INTO v_current_version
    FROM user_kana_states
    WHERE user_id = p_user_id
      AND kana_id = v_kana_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(s) INTO v_state
        FROM user_kana_states AS s
        WHERE user_id = p_user_id
          AND kana_id = v_kana_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_kana_states
        WHERE user_id = p_user_id
          AND kana_id = v_kana_id;

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'kana_id', v_kana_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    IF v_current_version IS NULL AND p_base_version IS NOT NULL AND p_base_version > 0 THEN
        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'MISSING_SERVER_ROW',
            'server_version', NULL,
            'server_state', NULL
        );
    END IF;

    INSERT INTO user_kana_states (
        user_id,
        kana_id,
        learning_status,
        next_review_at,
        last_reviewed_at,
        streak,
        total_reviews,
        fail_count,
        interval,
        ease_factor,
        stability,
        difficulty,
        source_device_id,
        last_mutation_id,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        v_kana_id,
        COALESCE((p_payload ->> 'learning_status')::INTEGER, 1),
        (p_payload ->> 'next_review_at')::BIGINT,
        (p_payload ->> 'last_reviewed_at')::BIGINT,
        COALESCE((p_payload ->> 'streak')::INTEGER, 0),
        COALESCE((p_payload ->> 'total_reviews')::INTEGER, 0),
        COALESCE((p_payload ->> 'fail_count')::INTEGER, 0),
        COALESCE((p_payload ->> 'interval')::DOUBLE PRECISION, 0),
        COALESCE((p_payload ->> 'ease_factor')::DOUBLE PRECISION, 2.5),
        COALESCE((p_payload ->> 'stability')::DOUBLE PRECISION, 0),
        COALESCE((p_payload ->> 'difficulty')::DOUBLE PRECISION, 0),
        p_device_id,
        p_mutation_id,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, kana_id) DO UPDATE SET
        learning_status = COALESCE((p_payload ->> 'learning_status')::INTEGER, user_kana_states.learning_status),
        next_review_at = CASE WHEN p_payload ? 'next_review_at' THEN (p_payload ->> 'next_review_at')::BIGINT ELSE user_kana_states.next_review_at END,
        last_reviewed_at = CASE WHEN p_payload ? 'last_reviewed_at' THEN (p_payload ->> 'last_reviewed_at')::BIGINT ELSE user_kana_states.last_reviewed_at END,
        streak = COALESCE((p_payload ->> 'streak')::INTEGER, user_kana_states.streak),
        total_reviews = COALESCE((p_payload ->> 'total_reviews')::INTEGER, user_kana_states.total_reviews),
        fail_count = COALESCE((p_payload ->> 'fail_count')::INTEGER, user_kana_states.fail_count),
        interval = COALESCE((p_payload ->> 'interval')::DOUBLE PRECISION, user_kana_states.interval),
        ease_factor = COALESCE((p_payload ->> 'ease_factor')::DOUBLE PRECISION, user_kana_states.ease_factor),
        stability = COALESCE((p_payload ->> 'stability')::DOUBLE PRECISION, user_kana_states.stability),
        difficulty = COALESCE((p_payload ->> 'difficulty')::DOUBLE PRECISION, user_kana_states.difficulty),
        source_device_id = p_device_id,
        last_mutation_id = p_mutation_id,
        updated_at = now(),
        version = user_kana_states.version + 1
    RETURNING version INTO v_result_version;

    SELECT to_jsonb(s) INTO v_state
    FROM user_kana_states AS s
    WHERE user_id = p_user_id
      AND kana_id = v_kana_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_grammar_state_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_grammar_id INTEGER := COALESCE((p_payload ->> 'grammar_id')::INTEGER, 0);
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_grammar_id <= 0 THEN
        RAISE EXCEPTION 'SYNC_GRAMMAR_STATE_REQUIRES_GRAMMAR_ID';
    END IF;

    SELECT version INTO v_current_version
    FROM user_grammar_states
    WHERE user_id = p_user_id
      AND grammar_id = v_grammar_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(s) INTO v_state
        FROM user_grammar_states AS s
        WHERE user_id = p_user_id
          AND grammar_id = v_grammar_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_grammar_states
        WHERE user_id = p_user_id
          AND grammar_id = v_grammar_id;

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'grammar_id', v_grammar_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    IF v_current_version IS NULL AND p_base_version IS NOT NULL AND p_base_version > 0 THEN
        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'MISSING_SERVER_ROW',
            'server_version', NULL,
            'server_state', NULL
        );
    END IF;

    INSERT INTO user_grammar_states (
        user_id,
        grammar_id,
        learning_status,
        next_review_at,
        last_reviewed_at,
        streak,
        total_reviews,
        fail_count,
        interval,
        ease_factor,
        stability,
        difficulty,
        source_device_id,
        last_mutation_id,
        created_at,
        updated_at,
        version
    ) VALUES (
        p_user_id,
        v_grammar_id,
        COALESCE((p_payload ->> 'learning_status')::INTEGER, 0),
        (p_payload ->> 'next_review_at')::BIGINT,
        (p_payload ->> 'last_reviewed_at')::BIGINT,
        COALESCE((p_payload ->> 'streak')::INTEGER, 0),
        COALESCE((p_payload ->> 'total_reviews')::INTEGER, 0),
        COALESCE((p_payload ->> 'fail_count')::INTEGER, 0),
        COALESCE((p_payload ->> 'interval')::DOUBLE PRECISION, 0),
        COALESCE((p_payload ->> 'ease_factor')::DOUBLE PRECISION, 2.5),
        COALESCE((p_payload ->> 'stability')::DOUBLE PRECISION, 0),
        COALESCE((p_payload ->> 'difficulty')::DOUBLE PRECISION, 0),
        p_device_id,
        p_mutation_id,
        now(),
        now(),
        1
    )
    ON CONFLICT (user_id, grammar_id) DO UPDATE SET
        learning_status = COALESCE((p_payload ->> 'learning_status')::INTEGER, user_grammar_states.learning_status),
        next_review_at = CASE WHEN p_payload ? 'next_review_at' THEN (p_payload ->> 'next_review_at')::BIGINT ELSE user_grammar_states.next_review_at END,
        last_reviewed_at = CASE WHEN p_payload ? 'last_reviewed_at' THEN (p_payload ->> 'last_reviewed_at')::BIGINT ELSE user_grammar_states.last_reviewed_at END,
        streak = COALESCE((p_payload ->> 'streak')::INTEGER, user_grammar_states.streak),
        total_reviews = COALESCE((p_payload ->> 'total_reviews')::INTEGER, user_grammar_states.total_reviews),
        fail_count = COALESCE((p_payload ->> 'fail_count')::INTEGER, user_grammar_states.fail_count),
        interval = COALESCE((p_payload ->> 'interval')::DOUBLE PRECISION, user_grammar_states.interval),
        ease_factor = COALESCE((p_payload ->> 'ease_factor')::DOUBLE PRECISION, user_grammar_states.ease_factor),
        stability = COALESCE((p_payload ->> 'stability')::DOUBLE PRECISION, user_grammar_states.stability),
        difficulty = COALESCE((p_payload ->> 'difficulty')::DOUBLE PRECISION, user_grammar_states.difficulty),
        source_device_id = p_device_id,
        last_mutation_id = p_mutation_id,
        updated_at = now(),
        version = user_grammar_states.version + 1
    RETURNING version INTO v_result_version;

    SELECT to_jsonb(s) INTO v_state
    FROM user_grammar_states AS s
    WHERE user_id = p_user_id
      AND grammar_id = v_grammar_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', v_result_version,
        'server_state', v_state,
        'event_payload', v_state,
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_apply_book_progress_mutation(
    p_user_id UUID,
    p_device_id UUID,
    p_payload JSONB,
    p_operation TEXT,
    p_mutation_id UUID,
    p_base_version BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_book_id TEXT := COALESCE(p_payload ->> 'book_id', '');
    v_current_version BIGINT;
    v_result_version BIGINT;
    v_state JSONB;
BEGIN
    IF v_book_id = '' THEN
        RAISE EXCEPTION 'SYNC_BOOK_PROGRESS_REQUIRES_BOOK_ID';
    END IF;

    SELECT version INTO v_current_version
    FROM user_book_progress
    WHERE user_id = p_user_id
      AND book_id = v_book_id
    FOR UPDATE;

    IF v_current_version IS NOT NULL AND p_base_version IS NOT NULL AND v_current_version <> p_base_version THEN
        SELECT to_jsonb(p) INTO v_state
        FROM user_book_progress AS p
        WHERE user_id = p_user_id
          AND book_id = v_book_id;

        RETURN jsonb_build_object(
            'status', 'conflict',
            'reason', 'VERSION_MISMATCH',
            'server_version', v_current_version,
            'server_state', COALESCE(v_state, '{}'::JSONB)
        );
    END IF;

    IF p_operation = 'delete' THEN
        IF v_current_version IS NULL THEN
            RETURN jsonb_build_object(
                'status', 'noop',
                'result_version', 0,
                'server_state', NULL,
                'event_payload', NULL
            );
        END IF;

        DELETE FROM user_book_progress
        WHERE user_id = p_user_id
          AND book_id = v_book_id;

        RETURN jsonb_build_object(
            'status', 'applied',
            'result_version', v_current_version + 1,
            'server_state', NULL,
            'event_payload', jsonb_build_object(
                'user_id', p_user_id,
                'book_id', v_book_id,
                'deleted', true,
                'version', v_current_version + 1
            ),
            'event_operation', 'delete'
        );
    END IF;

    PERFORM sync_rebuild_book_progress(p_user_id, v_book_id, p_payload);

    SELECT version, to_jsonb(p)
    INTO v_result_version, v_state
    FROM user_book_progress AS p
    WHERE user_id = p_user_id
      AND book_id = v_book_id;

    RETURN jsonb_build_object(
        'status', 'applied',
        'result_version', COALESCE(v_result_version, COALESCE(v_current_version, 0)),
        'server_state', COALESCE(v_state, '{}'::JSONB),
        'event_payload', COALESCE(v_state, '{}'::JSONB),
        'event_operation', COALESCE(NULLIF(p_operation, ''), 'upsert')
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_register_device(
    p_user_id UUID,
    p_device_id UUID,
    p_platform TEXT,
    p_device_name TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_server_cursor BIGINT := 0;
    v_bootstrap_required BOOLEAN := false;
BEGIN
    INSERT INTO user_devices (
        device_id,
        user_id,
        platform,
        device_name,
        app_version,
        last_seen_at,
        updated_at
    ) VALUES (
        p_device_id,
        p_user_id,
        p_platform,
        p_device_name,
        p_app_version,
        now(),
        now()
    )
    ON CONFLICT (device_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        platform = EXCLUDED.platform,
        device_name = EXCLUDED.device_name,
        app_version = EXCLUDED.app_version,
        last_seen_at = now(),
        updated_at = now();

    SELECT COALESCE(MAX(seq), 0) INTO v_server_cursor
    FROM user_sync_events
    WHERE user_id = p_user_id;

    SELECT EXISTS (
        SELECT 1 FROM user_profiles WHERE user_id = p_user_id
        UNION ALL
        SELECT 1 FROM user_word_states WHERE user_id = p_user_id LIMIT 1
    )
    OR EXISTS (SELECT 1 FROM user_word_favorites WHERE user_id = p_user_id LIMIT 1)
    OR EXISTS (SELECT 1 FROM user_word_example_favorites WHERE user_id = p_user_id LIMIT 1)
    OR EXISTS (SELECT 1 FROM user_kana_states WHERE user_id = p_user_id LIMIT 1)
    OR EXISTS (SELECT 1 FROM user_grammar_states WHERE user_id = p_user_id LIMIT 1)
    INTO v_bootstrap_required;

    RETURN jsonb_build_object(
        'data', jsonb_build_object(
            'device_id', p_device_id,
            'server_cursor', v_server_cursor::TEXT,
            'bootstrap_required', v_bootstrap_required
        ),
        'meta', jsonb_build_object(
            'server_time', now()
        )
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_bootstrap(
    p_user_id UUID,
    p_device_id UUID,
    p_cursor TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 200
) RETURNS JSONB AS $$
DECLARE
    v_profile JSONB := NULL;
    v_word_states JSONB := '[]'::JSONB;
    v_word_favorites JSONB := '[]'::JSONB;
    v_word_example_favorites JSONB := '[]'::JSONB;
    v_kana_states JSONB := '[]'::JSONB;
    v_grammar_states JSONB := '[]'::JSONB;
    v_book_progress JSONB := '[]'::JSONB;
    v_next_cursor BIGINT := 0;
BEGIN
    PERFORM sync_assert_device(p_user_id, p_device_id);

    SELECT to_jsonb(p) INTO v_profile
    FROM user_profiles AS p
    WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_word_states
    FROM (
        SELECT *
        FROM user_word_states
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_word_favorites
    FROM (
        SELECT *
        FROM user_word_favorites
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_word_example_favorites
    FROM (
        SELECT *
        FROM user_word_example_favorites
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_kana_states
    FROM (
        SELECT *
        FROM user_kana_states
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_grammar_states
    FROM (
        SELECT *
        FROM user_grammar_states
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB)
    INTO v_book_progress
    FROM (
        SELECT *
        FROM user_book_progress
        WHERE user_id = p_user_id
        ORDER BY updated_at ASC
        LIMIT GREATEST(p_limit, 1)
    ) AS s;

    SELECT COALESCE(MAX(seq), 0) INTO v_next_cursor
    FROM user_sync_events
    WHERE user_id = p_user_id;

    UPDATE user_devices
    SET last_seen_at = now(),
        last_pull_seq = GREATEST(last_pull_seq, v_next_cursor)
    WHERE user_id = p_user_id
      AND device_id = p_device_id;

    RETURN jsonb_build_object(
        'data', jsonb_build_object(
            'profile', v_profile,
            'word_states', v_word_states,
            'word_favorites', v_word_favorites,
            'word_example_favorites', v_word_example_favorites,
            'kana_states', v_kana_states,
            'grammar_states', v_grammar_states,
            'book_progress', v_book_progress
        ),
        'meta', jsonb_build_object(
            'next_cursor', v_next_cursor::TEXT,
            'has_more', false,
            'server_time', now()
        )
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_pull(
    p_user_id UUID,
    p_device_id UUID,
    p_after_seq BIGINT DEFAULT 0,
    p_limit INTEGER DEFAULT 200
) RETURNS JSONB AS $$
DECLARE
    v_events JSONB := '[]'::JSONB;
    v_next_cursor BIGINT := p_after_seq;
    v_has_more BOOLEAN := false;
BEGIN
    PERFORM sync_assert_device(p_user_id, p_device_id);

    WITH pulled AS (
        SELECT *
        FROM user_sync_events
        WHERE user_id = p_user_id
          AND seq > p_after_seq
        ORDER BY seq ASC
        LIMIT GREATEST(p_limit, 1)
    )
    SELECT
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'seq', seq,
                    'entity_type', entity_type,
                    'entity_key', entity_key,
                    'operation', operation,
                    'payload', payload,
                    'committed_at', committed_at
                )
                ORDER BY seq ASC
            ),
            '[]'::JSONB
        ),
        COALESCE(MAX(seq), p_after_seq),
        COUNT(*) = GREATEST(p_limit, 1)
    INTO v_events, v_next_cursor, v_has_more
    FROM pulled;

    UPDATE user_devices
    SET last_seen_at = now(),
        last_pull_seq = GREATEST(last_pull_seq, v_next_cursor)
    WHERE user_id = p_user_id
      AND device_id = p_device_id;

    RETURN jsonb_build_object(
        'data', v_events,
        'meta', jsonb_build_object(
            'next_cursor', v_next_cursor::TEXT,
            'has_more', v_has_more,
            'server_time', now()
        )
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_push(
    p_user_id UUID,
    p_device_id UUID,
    p_known_cursor TEXT DEFAULT NULL,
    p_mutations JSONB DEFAULT '[]'::JSONB
) RETURNS JSONB AS $$
DECLARE
    v_mutation JSONB;
    v_receipt RECORD;
    v_result JSONB;
    v_mutation_id UUID;
    v_entity_type TEXT;
    v_entity_key TEXT;
    v_operation TEXT;
    v_payload JSONB;
    v_base_version BIGINT;
    v_status TEXT;
    v_result_version BIGINT;
    v_event_payload JSONB;
    v_event_operation TEXT;
    v_acked JSONB := '[]'::JSONB;
    v_conflicts JSONB := '[]'::JSONB;
    v_next_cursor BIGINT := 0;
    v_ack_payload JSONB;
BEGIN
    PERFORM sync_assert_device(p_user_id, p_device_id);

    IF jsonb_typeof(p_mutations) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'SYNC_MUTATIONS_MUST_BE_ARRAY';
    END IF;

    FOR v_mutation IN
        SELECT value
        FROM jsonb_array_elements(p_mutations)
    LOOP
        v_mutation_id := (v_mutation ->> 'mutation_id')::UUID;
        v_entity_type := COALESCE(v_mutation ->> 'entity_type', '');
        v_entity_key := COALESCE(v_mutation ->> 'entity_key', '');
        v_operation := COALESCE(v_mutation ->> 'operation', 'upsert');
        v_payload := COALESCE(v_mutation -> 'payload', '{}'::JSONB);
        v_base_version := CASE
            WHEN v_mutation ? 'base_version' AND v_mutation ->> 'base_version' <> ''
                THEN (v_mutation ->> 'base_version')::BIGINT
            ELSE NULL
        END;

        PERFORM pg_advisory_xact_lock(
            hashtext(p_user_id::TEXT || ':' || p_device_id),
            hashtext(v_mutation_id::TEXT)
        );

        SELECT status, response_payload
        INTO v_receipt
        FROM sync_mutation_receipts
        WHERE user_id = p_user_id
          AND device_id = p_device_id
          AND mutation_id = v_mutation_id;

        IF FOUND THEN
            IF v_receipt.status = 'conflict' THEN
                v_conflicts := v_conflicts || jsonb_build_array(v_receipt.response_payload);
            ELSE
                v_acked := v_acked || jsonb_build_array(v_receipt.response_payload);
            END IF;
            CONTINUE;
        END IF;

        CASE v_entity_type
            WHEN 'profile' THEN
                v_result := sync_apply_profile_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'word_state' THEN
                v_result := sync_apply_word_state_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'word_favorite' THEN
                v_result := sync_apply_word_favorite_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'word_example_favorite' THEN
                v_result := sync_apply_word_example_favorite_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'kana_state' THEN
                v_result := sync_apply_kana_state_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'grammar_state' THEN
                v_result := sync_apply_grammar_state_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            WHEN 'book_progress' THEN
                v_result := sync_apply_book_progress_mutation(
                    p_user_id,
                    p_device_id,
                    v_payload,
                    v_operation,
                    v_mutation_id,
                    v_base_version
                );
            ELSE
                RAISE EXCEPTION 'SYNC_ENTITY_TYPE_NOT_SUPPORTED: %', v_entity_type;
        END CASE;

        v_status := COALESCE(v_result ->> 'status', 'applied');
        v_result_version := (v_result ->> 'result_version')::BIGINT;

        IF v_status = 'conflict' THEN
            v_ack_payload := jsonb_build_object(
                'mutation_id', v_mutation_id,
                'entity_type', v_entity_type,
                'entity_key', v_entity_key,
                'reason', COALESCE(v_result ->> 'reason', 'UNKNOWN_CONFLICT'),
                'server_version', v_result -> 'server_version',
                'server_state', v_result -> 'server_state'
            );

            INSERT INTO sync_mutation_receipts (
                user_id,
                device_id,
                mutation_id,
                entity_type,
                entity_key,
                base_version,
                result_version,
                status,
                response_payload,
                committed_at
            ) VALUES (
                p_user_id,
                p_device_id,
                v_mutation_id,
                v_entity_type,
                v_entity_key,
                v_base_version,
                NULL,
                'conflict',
                v_ack_payload,
                now()
            );

            v_conflicts := v_conflicts || jsonb_build_array(v_ack_payload);
            CONTINUE;
        END IF;

        v_event_payload := v_result -> 'event_payload';
        v_event_operation := COALESCE(v_result ->> 'event_operation', v_operation);

        IF v_status = 'applied' AND v_event_payload IS NOT NULL THEN
            INSERT INTO user_sync_events (
                user_id,
                device_id,
                entity_type,
                entity_key,
                operation,
                payload,
                committed_at
            ) VALUES (
                p_user_id,
                p_device_id,
                v_entity_type,
                v_entity_key,
                v_event_operation,
                v_event_payload,
                now()
            );
        END IF;

        v_ack_payload := jsonb_build_object(
            'mutation_id', v_mutation_id,
            'entity_type', v_entity_type,
            'entity_key', v_entity_key,
            'result_version', v_result_version,
            'status', v_status
        );

        INSERT INTO sync_mutation_receipts (
            user_id,
            device_id,
            mutation_id,
            entity_type,
            entity_key,
            base_version,
            result_version,
            status,
            response_payload,
            committed_at
        ) VALUES (
            p_user_id,
            p_device_id,
            v_mutation_id,
            v_entity_type,
            v_entity_key,
            v_base_version,
            v_result_version,
            CASE WHEN v_status = 'noop' THEN 'noop' ELSE 'applied' END,
            v_ack_payload,
            now()
        );

        v_acked := v_acked || jsonb_build_array(v_ack_payload);
    END LOOP;

    SELECT COALESCE(MAX(seq), 0) INTO v_next_cursor
    FROM user_sync_events
    WHERE user_id = p_user_id;

    UPDATE user_devices
    SET last_seen_at = now(),
        last_push_seq = GREATEST(last_push_seq, v_next_cursor)
    WHERE user_id = p_user_id
      AND device_id = p_device_id;

    RETURN jsonb_build_object(
        'data', jsonb_build_object(
            'acked_mutations', v_acked,
            'conflicts', v_conflicts
        ),
        'meta', jsonb_build_object(
            'next_cursor', v_next_cursor::TEXT,
            'server_time', now()
        )
    );
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------
-- 5.0 用户复习会话系统
-- --------------------------------------------------

-- 当前 Worker 仅保留 word review session。

CREATE TABLE IF NOT EXISTS user_review_sessions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_kind            TEXT NOT NULL,
    status                  TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
    current_index           INTEGER NOT NULL DEFAULT 0,
    current_phase           TEXT NOT NULL DEFAULT 'testing' CHECK (current_phase IN ('testing', 'grading')),
    has_mistake_on_current  BOOLEAN NOT NULL DEFAULT false,
    items                   JSONB NOT NULL DEFAULT '[]'::JSONB,
    closed_at               TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

DELETE FROM user_review_sessions
WHERE session_kind <> 'word';

ALTER TABLE user_review_sessions
    DROP CONSTRAINT IF EXISTS user_review_sessions_session_kind_check;
ALTER TABLE user_review_sessions
    ADD CONSTRAINT user_review_sessions_session_kind_check
    CHECK (session_kind = 'word');

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_review_sessions_active_kind
    ON user_review_sessions(user_id, session_kind)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_review_sessions_user_updated
    ON user_review_sessions(user_id, updated_at DESC);

DROP TRIGGER IF EXISTS trg_user_review_sessions_updated_at ON user_review_sessions;
CREATE TRIGGER trg_user_review_sessions_updated_at
    BEFORE UPDATE ON user_review_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE user_review_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated users can read own review sessions" ON user_review_sessions;
CREATE POLICY "authenticated users can read own review sessions"
    ON user_review_sessions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can upsert own review sessions" ON user_review_sessions;
CREATE POLICY "authenticated users can upsert own review sessions"
    ON user_review_sessions FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- =============================================================
-- 5.0 快照同步系统（替代旧的 mutation-event 体系）
-- 设计：单设备活跃，checkpoint = push(LWW) + pull 一次完成
-- =============================================================

-- 在 user_profiles 上追踪活跃设备
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS active_device_id UUID REFERENCES user_devices(device_id) ON DELETE SET NULL;

-- --------------------------------------------------
-- sync_checkpoint：唯一的同步接口
-- 逻辑：
--   1. 自动注册设备（如不存在）
--   2. LWW upsert 所有实体（按 updated_at 比较，客户端更新则覆盖）
--   3. favorites 做全集替换（NULL=跳过，[]或非空=替换）
--   4. 更新 active_device_id（接管主权）
--   5. 读取并返回当前服务端完整快照
--   返回 took_over=true 表示此次接管了之前另一台设备的会话
-- --------------------------------------------------
CREATE OR REPLACE FUNCTION sync_checkpoint(
    p_user_id                  UUID,
    p_device_id                UUID,
    p_platform                 TEXT       DEFAULT 'unknown',
    p_profile                  JSONB      DEFAULT NULL,
    p_word_states              JSONB      DEFAULT NULL,
    p_word_favorites           JSONB      DEFAULT NULL,
    p_word_example_favorites   JSONB      DEFAULT NULL,
    p_kana_states              JSONB      DEFAULT NULL,
    p_grammar_states           JSONB      DEFAULT NULL,
    p_book_progress            JSONB      DEFAULT NULL,
    p_force_takeover           BOOLEAN    DEFAULT false
) RETURNS JSONB AS $$
DECLARE
    v_prev_active_device UUID;
    v_took_over          BOOLEAN := false;
    v_displaced          BOOLEAN := false;
    v_profile            JSONB   := NULL;
    v_word_states        JSONB   := '[]';
    v_word_favorites     JSONB   := '[]';
    v_word_example_favs  JSONB   := '[]';
    v_kana_states        JSONB   := '[]';
    v_grammar_states     JSONB   := '[]';
    v_book_progress      JSONB   := '[]';
BEGIN
    -- ① 注册/更新设备
    INSERT INTO user_devices (device_id, user_id, platform, last_seen_at, created_at, updated_at)
    VALUES (p_device_id, p_user_id, p_platform, now(), now(), now())
    ON CONFLICT (device_id) DO UPDATE SET
        last_seen_at = now(),
        updated_at   = now();

    -- ② 检测设备接管 / 被踢下线
    SELECT active_device_id INTO v_prev_active_device
    FROM user_profiles WHERE user_id = p_user_id;

    IF v_prev_active_device IS NOT NULL AND v_prev_active_device <> p_device_id THEN
        IF p_force_takeover THEN
            v_took_over := true;
        ELSE
            v_displaced := true;
        END IF;
    END IF;

    -- ③ word_states：LWW upsert（按 updated_at）
    IF p_word_states IS NOT NULL AND jsonb_array_length(p_word_states) > 0 THEN
        INSERT INTO user_word_states (
            user_id, word_id, book_id, user_state,
            next_review_at, last_reviewed_at, first_learned_at,
            interval, ease_factor, stability, difficulty,
            streak, total_reviews, fail_count,
            source_device_id, created_at, updated_at, version
        )
        SELECT
            p_user_id,
            elem->>'word_id',
            elem->>'book_id',
            COALESCE((elem->>'user_state')::INTEGER, 0),
            (NULLIF(elem->>'next_review_at',   ''))::BIGINT,
            (NULLIF(elem->>'last_reviewed_at', ''))::BIGINT,
            (NULLIF(elem->>'first_learned_at', ''))::BIGINT,
            (NULLIF(elem->>'interval',         ''))::INTEGER,
            (NULLIF(elem->>'ease_factor',      ''))::DOUBLE PRECISION,
            (NULLIF(elem->>'stability',        ''))::DOUBLE PRECISION,
            (NULLIF(elem->>'difficulty',       ''))::DOUBLE PRECISION,
            COALESCE((elem->>'streak')::INTEGER,        0),
            COALESCE((elem->>'total_reviews')::INTEGER, 0),
            COALESCE((elem->>'fail_count')::INTEGER,    0),
            p_device_id,
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
            COALESCE((elem->>'version')::BIGINT, 1)
        FROM jsonb_array_elements(p_word_states) AS elem
        WHERE (elem->>'word_id') IS NOT NULL AND (elem->>'book_id') IS NOT NULL
        ON CONFLICT (user_id, word_id, book_id) DO UPDATE SET
            user_state       = EXCLUDED.user_state,
            next_review_at   = EXCLUDED.next_review_at,
            last_reviewed_at = EXCLUDED.last_reviewed_at,
            first_learned_at = EXCLUDED.first_learned_at,
            interval         = EXCLUDED.interval,
            ease_factor      = EXCLUDED.ease_factor,
            stability        = EXCLUDED.stability,
            difficulty       = EXCLUDED.difficulty,
            streak           = EXCLUDED.streak,
            total_reviews    = EXCLUDED.total_reviews,
            fail_count       = EXCLUDED.fail_count,
            source_device_id = EXCLUDED.source_device_id,
            updated_at       = EXCLUDED.updated_at,
            version          = user_word_states.version + 1
        WHERE EXCLUDED.updated_at >= user_word_states.updated_at;
    END IF;

    -- ④ word_favorites：全集替换（NULL=跳过；被踢下线时跳过，避免覆盖活跃设备数据）
    IF p_word_favorites IS NOT NULL AND NOT v_displaced THEN
        DELETE FROM user_word_favorites WHERE user_id = p_user_id;
        IF jsonb_array_length(p_word_favorites) > 0 THEN
            INSERT INTO user_word_favorites (user_id, word_id, book_id, source_device_id, created_at, updated_at, version)
            SELECT
                p_user_id,
                elem->>'word_id',
                COALESCE(elem->>'book_id', ''),
                p_device_id,
                COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
                COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
                COALESCE((elem->>'version')::BIGINT, 1)
            FROM jsonb_array_elements(p_word_favorites) AS elem
            WHERE (elem->>'word_id') IS NOT NULL;
        END IF;
    END IF;

    -- ⑤ word_example_favorites：全集替换（NULL=跳过；被踢下线时跳过）
    IF p_word_example_favorites IS NOT NULL AND NOT v_displaced THEN
        DELETE FROM user_word_example_favorites WHERE user_id = p_user_id;
        IF jsonb_array_length(p_word_example_favorites) > 0 THEN
            INSERT INTO user_word_example_favorites (user_id, example_id, word_id, source_device_id, created_at, updated_at, version)
            SELECT
                p_user_id,
                elem->>'example_id',
                elem->>'word_id',
                p_device_id,
                COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
                COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
                COALESCE((elem->>'version')::BIGINT, 1)
            FROM jsonb_array_elements(p_word_example_favorites) AS elem
            WHERE (elem->>'example_id') IS NOT NULL;
        END IF;
    END IF;

    -- ⑥ kana_states：LWW upsert
    IF p_kana_states IS NOT NULL AND jsonb_array_length(p_kana_states) > 0 THEN
        INSERT INTO user_kana_states (
            user_id, kana_id, learning_status,
            next_review_at, last_reviewed_at,
            streak, total_reviews, fail_count,
            interval, ease_factor, stability, difficulty,
            source_device_id, created_at, updated_at, version
        )
        SELECT
            p_user_id,
            (elem->>'kana_id')::INTEGER,
            COALESCE((elem->>'learning_status')::INTEGER, 0),
            (NULLIF(elem->>'next_review_at',   ''))::BIGINT,
            (NULLIF(elem->>'last_reviewed_at', ''))::BIGINT,
            COALESCE((elem->>'streak')::INTEGER,        0),
            COALESCE((elem->>'total_reviews')::INTEGER, 0),
            COALESCE((elem->>'fail_count')::INTEGER,    0),
            COALESCE((elem->>'interval')::DOUBLE PRECISION,   0),
            COALESCE((elem->>'ease_factor')::DOUBLE PRECISION, 2.5),
            COALESCE((elem->>'stability')::DOUBLE PRECISION,  0),
            COALESCE((elem->>'difficulty')::DOUBLE PRECISION, 0),
            p_device_id,
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
            COALESCE((elem->>'version')::BIGINT, 1)
        FROM jsonb_array_elements(p_kana_states) AS elem
        WHERE (elem->>'kana_id') IS NOT NULL
        ON CONFLICT (user_id, kana_id) DO UPDATE SET
            learning_status  = EXCLUDED.learning_status,
            next_review_at   = EXCLUDED.next_review_at,
            last_reviewed_at = EXCLUDED.last_reviewed_at,
            streak           = EXCLUDED.streak,
            total_reviews    = EXCLUDED.total_reviews,
            fail_count       = EXCLUDED.fail_count,
            interval         = EXCLUDED.interval,
            ease_factor      = EXCLUDED.ease_factor,
            stability        = EXCLUDED.stability,
            difficulty       = EXCLUDED.difficulty,
            source_device_id = EXCLUDED.source_device_id,
            updated_at       = EXCLUDED.updated_at,
            version          = user_kana_states.version + 1
        WHERE EXCLUDED.updated_at >= user_kana_states.updated_at;
    END IF;

    -- ⑦ grammar_states：LWW upsert
    IF p_grammar_states IS NOT NULL AND jsonb_array_length(p_grammar_states) > 0 THEN
        INSERT INTO user_grammar_states (
            user_id, grammar_id, learning_status,
            next_review_at, last_reviewed_at,
            streak, total_reviews, fail_count,
            interval, ease_factor, stability, difficulty,
            source_device_id, created_at, updated_at, version
        )
        SELECT
            p_user_id,
            (elem->>'grammar_id')::INTEGER,
            COALESCE((elem->>'learning_status')::INTEGER, 0),
            (NULLIF(elem->>'next_review_at',   ''))::BIGINT,
            (NULLIF(elem->>'last_reviewed_at', ''))::BIGINT,
            COALESCE((elem->>'streak')::INTEGER,        0),
            COALESCE((elem->>'total_reviews')::INTEGER, 0),
            COALESCE((elem->>'fail_count')::INTEGER,    0),
            COALESCE((elem->>'interval')::DOUBLE PRECISION,   0),
            COALESCE((elem->>'ease_factor')::DOUBLE PRECISION, 2.5),
            COALESCE((elem->>'stability')::DOUBLE PRECISION,  0),
            COALESCE((elem->>'difficulty')::DOUBLE PRECISION, 0),
            p_device_id,
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
            COALESCE((elem->>'version')::BIGINT, 1)
        FROM jsonb_array_elements(p_grammar_states) AS elem
        WHERE (elem->>'grammar_id') IS NOT NULL
        ON CONFLICT (user_id, grammar_id) DO UPDATE SET
            learning_status  = EXCLUDED.learning_status,
            next_review_at   = EXCLUDED.next_review_at,
            last_reviewed_at = EXCLUDED.last_reviewed_at,
            streak           = EXCLUDED.streak,
            total_reviews    = EXCLUDED.total_reviews,
            fail_count       = EXCLUDED.fail_count,
            interval         = EXCLUDED.interval,
            ease_factor      = EXCLUDED.ease_factor,
            stability        = EXCLUDED.stability,
            difficulty       = EXCLUDED.difficulty,
            source_device_id = EXCLUDED.source_device_id,
            updated_at       = EXCLUDED.updated_at,
            version          = user_grammar_states.version + 1
        WHERE EXCLUDED.updated_at >= user_grammar_states.updated_at;
    END IF;

    -- ⑧ book_progress：LWW upsert（cursor 单调递增）
    IF p_book_progress IS NOT NULL AND jsonb_array_length(p_book_progress) > 0 THEN
        INSERT INTO user_book_progress (
            user_id, book_id,
            total_words, learned_count, mastered_count, ignored_count,
            is_completed, current_sort_cursor,
            created_at, updated_at, version
        )
        SELECT
            p_user_id,
            elem->>'book_id',
            COALESCE((elem->>'total_words')::INTEGER,    0),
            COALESCE((elem->>'learned_count')::INTEGER,  0),
            COALESCE((elem->>'mastered_count')::INTEGER, 0),
            COALESCE((elem->>'ignored_count')::INTEGER,  0),
            COALESCE((elem->>'is_completed')::BOOLEAN,   false),
            COALESCE((elem->>'current_sort_cursor')::INTEGER, 0),
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
            COALESCE((elem->>'version')::BIGINT, 1)
        FROM jsonb_array_elements(p_book_progress) AS elem
        WHERE (elem->>'book_id') IS NOT NULL
        ON CONFLICT (user_id, book_id) DO UPDATE SET
            total_words          = EXCLUDED.total_words,
            learned_count        = EXCLUDED.learned_count,
            mastered_count       = EXCLUDED.mastered_count,
            ignored_count        = EXCLUDED.ignored_count,
            is_completed         = EXCLUDED.is_completed,
            current_sort_cursor  = GREATEST(user_book_progress.current_sort_cursor, EXCLUDED.current_sort_cursor),
            updated_at           = EXCLUDED.updated_at,
            version              = user_book_progress.version + 1
        WHERE EXCLUDED.updated_at >= user_book_progress.updated_at;
    END IF;

    -- ⑨ profile：LWW upsert + 更新 active_device_id
    IF p_profile IS NOT NULL THEN
        INSERT INTO user_profiles (
            user_id, display_name, email, avatar_url, locale, timezone,
            settings, onboarding_completed, pro_status,
            active_device_id, created_at, updated_at, version
        ) VALUES (
            p_user_id,
            p_profile->>'display_name',
            p_profile->>'email',
            p_profile->>'avatar_url',
            COALESCE(p_profile->>'locale', 'zh'),
            p_profile->>'timezone',
            COALESCE(p_profile->'settings', '{}'::JSONB),
            COALESCE((p_profile->>'onboarding_completed')::BOOLEAN, false),
            COALESCE((p_profile->>'pro_status')::SMALLINT, 0),
            p_device_id, now(), now(), 1
        )
        ON CONFLICT (user_id) DO UPDATE SET
            display_name         = COALESCE(p_profile->>'display_name',               user_profiles.display_name),
            email                = COALESCE(p_profile->>'email',                       user_profiles.email),
            avatar_url           = COALESCE(p_profile->>'avatar_url',                 user_profiles.avatar_url),
            locale               = COALESCE(p_profile->>'locale',                     user_profiles.locale),
            timezone             = COALESCE(p_profile->>'timezone',                   user_profiles.timezone),
            settings             = COALESCE(p_profile->'settings',                    user_profiles.settings),
            onboarding_completed = COALESCE((p_profile->>'onboarding_completed')::BOOLEAN, user_profiles.onboarding_completed),
            pro_status           = COALESCE((p_profile->>'pro_status')::SMALLINT,     user_profiles.pro_status),
            active_device_id     = CASE WHEN v_displaced THEN user_profiles.active_device_id ELSE p_device_id END,
            updated_at           = now(),
            version              = user_profiles.version + 1;
    ELSE
        -- 没有 profile 数据时，也要更新 active_device_id
        INSERT INTO user_profiles (user_id, active_device_id, created_at, updated_at, version)
        VALUES (p_user_id, p_device_id, now(), now(), 1)
        ON CONFLICT (user_id) DO UPDATE SET
            active_device_id = CASE WHEN v_displaced THEN user_profiles.active_device_id ELSE p_device_id END,
            updated_at       = now();
    END IF;

    -- ⑩ 读取当前完整快照并返回
    SELECT to_jsonb(p) INTO v_profile
    FROM user_profiles p WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB) INTO v_word_states
    FROM user_word_states s WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(f) ORDER BY f.updated_at ASC), '[]'::JSONB) INTO v_word_favorites
    FROM user_word_favorites f WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(f) ORDER BY f.updated_at ASC), '[]'::JSONB) INTO v_word_example_favs
    FROM user_word_example_favorites f WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB) INTO v_kana_states
    FROM user_kana_states s WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.updated_at ASC), '[]'::JSONB) INTO v_grammar_states
    FROM user_grammar_states s WHERE user_id = p_user_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(b) ORDER BY b.updated_at ASC), '[]'::JSONB) INTO v_book_progress
    FROM user_book_progress b WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'data', jsonb_build_object(
            'profile',                  v_profile,
            'word_states',              v_word_states,
            'word_favorites',           v_word_favorites,
            'word_example_favorites',   v_word_example_favs,
            'kana_states',              v_kana_states,
            'grammar_states',           v_grammar_states,
            'book_progress',            v_book_progress
        ),
        'meta', jsonb_build_object(
            'server_time',      now(),
            'active_device_id', CASE WHEN v_displaced THEN v_prev_active_device ELSE p_device_id END,
            'took_over',        v_took_over,
            'displaced',        v_displaced
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';

-- --------------------------------------------------
-- 完成
-- --------------------------------------------------
