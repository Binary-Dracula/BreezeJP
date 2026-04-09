// Workers 环境变量和绑定类型定义

export interface Env {
  // KV 命名空间（缓存）
  CACHE: KVNamespace;
  // R2 存储桶（音频）
  AUDIO_BUCKET: R2Bucket;
  // 环境变量（非敏感，定义在 wrangler.toml [vars]）
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  CACHE_TTL_ARTICLES: string;
  CACHE_TTL_DETAIL: string;
  // 敏感变量（通过 wrangler secret put 设置）
  SUPABASE_SERVICE_KEY: string;
  JWT_SECRET: string;
}

// 新闻列表项（轻量）
export interface ArticleListItem {
  id: string;
  title: string;
  clean_title: string;
  published_at: string;
  audio_url: string;
  duration_ms: number;
  sentence_count: number;
  is_archived: boolean;
}

// 分词 word 完整结构（与 Sudachi 输出一致）
export interface Word {
  word_id: number;
  word_type: string;
  word_position: number;
  surface_form: string;
  pos: string;
  pos_detail_1: string;
  pos_detail_2: string;
  pos_detail_3: string;
  conjugated_type: string;
  conjugated_form: string;
  basic_form: string;
  reading: string;
  pronunciation: string;
  furigana: string;
  ruby_text: string;
  normalized_form?: string;
}

// 句子 item
export interface SentenceItem {
  text: string;
  translation: string;
  start_ms: number | null;
  end_ms: number | null;
  index: number;
  words: Word[];
}

// 新闻详情（含完整句子数组）
export interface ArticleDetail extends ArticleListItem {
  items: SentenceItem[];
}

// --- BreezeJP 2.0 Vocabulary System ---

export interface VocabBook {
  id: string;
  title: string;
  subtitle?: string;
  description?: string;
  cover_image_key?: string;
  has_lessons: boolean;
  word_count: number;
}

export interface VocabLesson {
  id: string;
  book_id: string;
  lesson_number: number;
  title?: string;
  word_count: number;
}

export interface VocabWord {
  id: string;
  word: string;
  reading: string;
  romaji?: string;
  pitch_accent?: string;
  jlpt_level?: string;
  part_of_speech: string;
  transitivity?: string;
  primary_meaning?: string;
  has_audio: boolean;
}

export interface VocabWordDetail {
  word_id: string;
  rich_content: {
    meanings: any[];
    grammar_rules?: any[];
    conjugations?: any;
    kanji_components?: any[];
    synonyms_antonyms?: any;
    collocations?: any[];
    common_mistakes?: any[];
    _source_meta?: any;
  };
}

export interface VocabExample {
  id: string;
  word_id: string;
  level: string;
  japanese: string;
  chinese: string;
  has_audio: boolean;
  sort_order: number;
}

export interface VocabFullDetail extends VocabWord {
  rich_content: VocabWordDetail['rich_content'];
  examples: VocabExample[];
}

// API 统一响应格式
export interface ApiResponse<T> {
  data: T;
  meta?: Record<string, unknown> & { server_time?: string };
}

export interface ApiError {
  error: {
    code: string;
    message: string;
  };
}

// 分页元信息
export interface PaginationMeta {
  total: number;
  has_more: boolean;
  cursor: string | null;
  server_time: string;
}
