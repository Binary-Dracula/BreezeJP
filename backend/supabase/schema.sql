-- =============================================================
-- BreezeJP Supabase 数据库 Schema
-- 项目: eecfrzvutrhftwvyebpq.supabase.co
-- =============================================================

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

CREATE TRIGGER trg_articles_updated_at
    BEFORE UPDATE ON articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

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

-- --------------------------------------------------
-- 完成
-- --------------------------------------------------
