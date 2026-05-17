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

CREATE TABLE IF NOT EXISTS user_learning_sessions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         UUID,
    book_id           TEXT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
    word_ids          TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    words_payload     JSONB NOT NULL DEFAULT '[]'::JSONB,
    batch_start_sort  INTEGER NOT NULL,
    batch_end_sort    INTEGER NOT NULL,
    completed_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_learning_sessions_active_book
    ON user_learning_sessions(user_id, book_id)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_learning_sessions_user_updated
    ON user_learning_sessions(user_id, updated_at DESC);

ALTER TABLE user_learning_sessions
    ALTER COLUMN device_id DROP NOT NULL;

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

DROP TRIGGER IF EXISTS trg_user_learning_sessions_updated_at ON user_learning_sessions;
CREATE TRIGGER trg_user_learning_sessions_updated_at
    BEFORE UPDATE ON user_learning_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_example_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_kana_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_grammar_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_book_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_learning_sessions ENABLE ROW LEVEL SECURITY;

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

DROP POLICY IF EXISTS "authenticated users can read own learning sessions" ON user_learning_sessions;
CREATE POLICY "authenticated users can read own learning sessions"
    ON user_learning_sessions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "authenticated users can manage own learning sessions" ON user_learning_sessions;
CREATE POLICY "authenticated users can manage own learning sessions"
    ON user_learning_sessions FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

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

-- --------------------------------------------------
-- 5.0 用户复习会话系统
-- --------------------------------------------------

-- review session 支持 word / kana 两类队列。

CREATE TABLE IF NOT EXISTS user_review_sessions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_kind            TEXT NOT NULL,
    status                  TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
    current_index           INTEGER NOT NULL DEFAULT 0,
    items                   JSONB NOT NULL DEFAULT '[]'::JSONB,
    closed_at               TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_review_sessions
    DROP COLUMN IF EXISTS current_phase;
ALTER TABLE user_review_sessions
    DROP COLUMN IF EXISTS has_mistake_on_current;

ALTER TABLE user_review_sessions
    DROP CONSTRAINT IF EXISTS user_review_sessions_session_kind_check;
ALTER TABLE user_review_sessions
    ADD CONSTRAINT user_review_sessions_session_kind_check
    CHECK (session_kind IN ('word', 'kana'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_review_sessions_active_kind
    ON user_review_sessions(user_id, session_kind)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_review_sessions_user_updated
    ON user_review_sessions(user_id, updated_at DESC);

CREATE OR REPLACE FUNCTION complete_word_review_session(
    p_user_id UUID,
    p_session_id UUID,
    p_word_states JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id UUID;
    v_state_count INTEGER := 0;
BEGIN
    UPDATE user_review_sessions
    SET status = 'completed',
        current_index = 0,
        closed_at = now(),
        updated_at = now()
    WHERE id = p_session_id
      AND user_id = p_user_id
      AND session_kind = 'word'
      AND status = 'active'
    RETURNING id INTO v_session_id;

    IF v_session_id IS NULL THEN
        RETURN jsonb_build_object(
            'applied', false,
            'reason', 'STALE_SESSION'
        );
    END IF;

    IF p_word_states IS NOT NULL
       AND jsonb_typeof(p_word_states) = 'array'
       AND jsonb_array_length(p_word_states) > 0 THEN
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
            COALESCE((elem->>'user_state')::INTEGER, 1),
            (NULLIF(elem->>'next_review_at', ''))::BIGINT,
            (NULLIF(elem->>'last_reviewed_at', ''))::BIGINT,
            (NULLIF(elem->>'first_learned_at', ''))::BIGINT,
            (NULLIF(elem->>'interval', ''))::INTEGER,
            (NULLIF(elem->>'ease_factor', ''))::DOUBLE PRECISION,
            COALESCE((elem->>'stability')::DOUBLE PRECISION, 0),
            COALESCE((elem->>'difficulty')::DOUBLE PRECISION, 0),
            COALESCE((elem->>'streak')::INTEGER, 0),
            COALESCE((elem->>'total_reviews')::INTEGER, 0),
            COALESCE((elem->>'fail_count')::INTEGER, 0),
            NULL,
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now()),
            COALESCE((elem->>'version')::BIGINT, 1)
        FROM jsonb_array_elements(p_word_states) AS elem
        WHERE COALESCE(elem->>'word_id', '') <> ''
          AND COALESCE(elem->>'book_id', '') <> ''
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
            updated_at       = EXCLUDED.updated_at,
            version          = user_word_states.version + 1;

        GET DIAGNOSTICS v_state_count = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object(
        'applied', true,
        'session_id', v_session_id,
        'state_count', v_state_count
    );
END;
$$;

CREATE OR REPLACE FUNCTION complete_kana_review_session(
    p_user_id UUID,
    p_session_id UUID,
    p_kana_states JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id UUID;
    v_state_count INTEGER := 0;
BEGIN
    UPDATE user_review_sessions
    SET status = 'completed',
        current_index = 0,
        closed_at = now(),
        updated_at = now()
    WHERE id = p_session_id
      AND user_id = p_user_id
      AND session_kind = 'kana'
      AND status = 'active'
    RETURNING id INTO v_session_id;

    IF v_session_id IS NULL THEN
        RETURN jsonb_build_object(
            'applied', false,
            'reason', 'STALE_SESSION'
        );
    END IF;

    IF p_kana_states IS NOT NULL
       AND jsonb_typeof(p_kana_states) = 'array'
       AND jsonb_array_length(p_kana_states) > 0 THEN
        INSERT INTO user_kana_states (
            user_id, kana_id, learning_status,
            next_review_at, last_reviewed_at,
            interval, ease_factor, stability, difficulty,
            streak, total_reviews, fail_count,
            source_device_id, created_at, updated_at
        )
        SELECT
            p_user_id,
            (elem->>'kana_id')::INTEGER,
            COALESCE((elem->>'learning_status')::INTEGER, 1),
            (NULLIF(elem->>'next_review_at', ''))::BIGINT,
            (NULLIF(elem->>'last_reviewed_at', ''))::BIGINT,
            COALESCE((NULLIF(elem->>'interval', ''))::DOUBLE PRECISION, 0),
            COALESCE((NULLIF(elem->>'ease_factor', ''))::DOUBLE PRECISION, 2.5),
            COALESCE((NULLIF(elem->>'stability', ''))::DOUBLE PRECISION, 0),
            COALESCE((NULLIF(elem->>'difficulty', ''))::DOUBLE PRECISION, 0),
            COALESCE((elem->>'streak')::INTEGER, 0),
            COALESCE((elem->>'total_reviews')::INTEGER, 0),
            COALESCE((elem->>'fail_count')::INTEGER, 0),
            NULL,
            COALESCE(to_timestamp((elem->>'created_at')::BIGINT), now()),
            COALESCE(to_timestamp((elem->>'updated_at')::BIGINT), now())
        FROM jsonb_array_elements(p_kana_states) AS elem
        WHERE COALESCE(elem->>'kana_id', '') <> ''
        ON CONFLICT (user_id, kana_id) DO UPDATE SET
            learning_status  = EXCLUDED.learning_status,
            next_review_at   = EXCLUDED.next_review_at,
            last_reviewed_at = EXCLUDED.last_reviewed_at,
            interval         = EXCLUDED.interval,
            ease_factor      = EXCLUDED.ease_factor,
            stability        = EXCLUDED.stability,
            difficulty       = EXCLUDED.difficulty,
            streak           = EXCLUDED.streak,
            total_reviews    = EXCLUDED.total_reviews,
            fail_count       = EXCLUDED.fail_count,
            updated_at       = EXCLUDED.updated_at;

        GET DIAGNOSTICS v_state_count = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object(
        'applied', true,
        'session_id', v_session_id,
        'state_count', v_state_count
    );
END;
$$;

CREATE OR REPLACE FUNCTION complete_word_learning_session(
    p_user_id UUID,
    p_session_id UUID,
    p_word_states JSONB DEFAULT '[]'::JSONB,
    p_total_words INTEGER DEFAULT 0,
    p_first_review_interval_minutes INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id UUID;
    v_book_id TEXT;
    v_batch_end_sort INTEGER;
    v_state_count INTEGER := 0;
    v_now_seconds BIGINT := EXTRACT(EPOCH FROM now())::BIGINT;
    v_first_review_seconds BIGINT := EXTRACT(EPOCH FROM now() + make_interval(mins => GREATEST(COALESCE(p_first_review_interval_minutes, 10), 1)))::BIGINT;
BEGIN
    UPDATE user_learning_sessions
    SET status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = p_session_id
      AND user_id = p_user_id
      AND status = 'active'
    RETURNING id, book_id, batch_end_sort
    INTO v_session_id, v_book_id, v_batch_end_sort;

    IF v_session_id IS NULL THEN
        RETURN jsonb_build_object(
            'applied', false,
            'reason', 'STALE_SESSION'
        );
    END IF;

    IF p_word_states IS NOT NULL
       AND jsonb_typeof(p_word_states) = 'array'
       AND jsonb_array_length(p_word_states) > 0 THEN
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
            COALESCE(NULLIF(elem->>'book_id', ''), v_book_id),
            COALESCE((elem->>'user_state')::INTEGER, 1),
            CASE
                WHEN COALESCE((elem->>'user_state')::INTEGER, 1) = 1 THEN v_first_review_seconds
                ELSE NULL
            END,
            CASE
                WHEN COALESCE((elem->>'user_state')::INTEGER, 1) = 1 THEN v_now_seconds
                ELSE NULL
            END,
            v_now_seconds,
            NULL,
            NULL,
            NULL,
            NULL,
            0,
            0,
            0,
            NULL,
            now(),
            now(),
            1
        FROM jsonb_array_elements(p_word_states) AS elem
        WHERE COALESCE(elem->>'word_id', '') <> ''
        ON CONFLICT (user_id, word_id, book_id) DO UPDATE SET
            user_state       = EXCLUDED.user_state,
            next_review_at   = EXCLUDED.next_review_at,
            last_reviewed_at = EXCLUDED.last_reviewed_at,
            first_learned_at = COALESCE(user_word_states.first_learned_at, EXCLUDED.first_learned_at),
            interval         = EXCLUDED.interval,
            ease_factor      = EXCLUDED.ease_factor,
            stability        = EXCLUDED.stability,
            difficulty       = EXCLUDED.difficulty,
            streak           = EXCLUDED.streak,
            total_reviews    = EXCLUDED.total_reviews,
            fail_count       = EXCLUDED.fail_count,
            updated_at       = now(),
            version          = user_word_states.version + 1;

        GET DIAGNOSTICS v_state_count = ROW_COUNT;
    END IF;

    PERFORM sync_rebuild_book_progress(
        p_user_id,
        v_book_id,
        jsonb_build_object(
            'current_sort_cursor', v_batch_end_sort,
            'total_words', GREATEST(COALESCE(p_total_words, 0), 0)
        )
    );

    RETURN jsonb_build_object(
        'applied', true,
        'session_id', v_session_id,
        'book_id', v_book_id,
        'next_cursor', v_batch_end_sort,
        'state_count', v_state_count
    );
END;
$$;

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
-- 5.0 清理已废弃的快照同步系统
-- =============================================================

DO $$
DECLARE
    function_record RECORD;
BEGIN
    FOR function_record IN
        SELECT n.nspname AS schema_name,
               p.proname AS function_name,
               pg_get_function_identity_arguments(p.oid) AS argument_list
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND (
              p.proname IN (
                  'sync_assert_device',
                  'sync_bootstrap',
                  'sync_checkpoint',
                  'sync_pull',
                  'sync_push',
                  'sync_register_device'
              )
              OR p.proname LIKE 'sync_apply_%'
          )
    LOOP
        EXECUTE format(
            'DROP FUNCTION IF EXISTS %I.%I(%s)',
            function_record.schema_name,
            function_record.function_name,
            function_record.argument_list
        );
    END LOOP;
END $$;

ALTER TABLE user_profiles
    DROP COLUMN IF EXISTS active_device_id;

DROP TABLE IF EXISTS sync_mutation_receipts;
DROP TABLE IF EXISTS user_sync_events;

NOTIFY pgrst, 'reload schema';

-- --------------------------------------------------
-- 完成
-- --------------------------------------------------
