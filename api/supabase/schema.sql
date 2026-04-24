-- =============================================================
-- BreezeJP Supabase 数据库 Schema
-- 项目: eecfrzvutrhftwvyebpq.supabase.co
-- =============================================================

-- =============================================================
-- [DANGER ZONE] 重置：删除所有旧表与函数
-- 因为新闻数据尚且没有部署到 Supabase 中，在此一并重建
DROP TABLE IF EXISTS articles CASCADE;
DROP TABLE IF EXISTS article_details CASCADE;
-- =============================================================
DROP TABLE IF EXISTS lesson_word_map CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS word_examples CASCADE;
DROP TABLE IF EXISTS word_details CASCADE;
DROP TABLE IF EXISTS words CASCADE;
DROP TABLE IF EXISTS sync_metadata CASCADE;

DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

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
CREATE POLICY "authenticated users can read articles"
    ON articles FOR SELECT
    TO authenticated
    USING (true);

-- article_details：任何已登录用户可读
CREATE POLICY "authenticated users can read article_details"
    ON article_details FOR SELECT
    TO authenticated
    USING (true);

-- sync_metadata：任何已登录用户可读
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
-- 5. Row Level Security (RLS) policies 扩展
-- --------------------------------------------------
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_examples ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_word_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated users can read words" ON words FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated users can read word_details" ON word_details FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated users can read word_examples" ON word_examples FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated users can read books" ON books FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated users can read lessons" ON lessons FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated users can read lesson_word_map" ON lesson_word_map FOR SELECT TO authenticated USING (true);

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
CREATE POLICY "authenticated users can insert own issues"
    ON issue_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 已登录用户可以读取自己的上报
CREATE POLICY "authenticated users can read own issues"
    ON issue_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 注意：管理后台使用 service_role 绕过 RLS 进行全量读写

-- --------------------------------------------------
-- 完成
-- --------------------------------------------------
