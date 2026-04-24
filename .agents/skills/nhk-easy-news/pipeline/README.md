# NHK Easy News 爬虫与数据处理工具链

从 NHK NEWS WEB EASY 获取新闻（带注音）及配音录音，通过 Sudachi 分词处理，生成供 App 消费的结构化数据。

## 目录结构

```
.agents/skills/nhk-easy-news/pipeline/
├── scripts/                    # 所有脚本
│   ├── nhk_scraper.py          # 核心爬虫（抓取+音频下载）
│   ├── align.py                # 音频-文本时间戳对齐（faster-whisper）
│   ├── process_all_sudachi.py  # Sudachi 批量分词处理 (默认使用)
│   ├── process_all.js          # Kuromoji 批量分词处理 (备选)
│   ├── translate_json.py       # ZhipuAI 机器翻译
│   ├── convert_to_mock.js      # 转换为 App mock 格式
│   └── run_pipeline.sh         # 一键执行全管道
├── data/                       # 所有文章数据（一篇文章一个文件夹）
│   └── {article_id}/
│       ├── raw.json            # 爬虫原始数据（以句子为单位）
│       ├── {article_id}.mp3    # 音频文件
│       ├── aligned.json        # 音频对齐数据
│       └── processed.json      # Sudachi 分词及翻译后的最终数据
├── HOW_TO_GET_TOKEN.md         # Token 获取指南
├── venv/                       # Python 虚拟环境
├── node_modules/               # Node.js 依赖
├── requirements.txt            # Python 依赖
└── package.json                # Node.js 依赖
```

## 快速开始

```bash
# 1. (可选) 配置智谱大模型 API Key（用于句子翻译）
export ZHIPU_API_KEY="你的_API_KEY"

# 2. 从浏览器获取 hdnts Token（详见 HOW_TO_GET_TOKEN.md）
# 3. 一键执行全管道
bash scripts/run_pipeline.sh --hdnts "exp=...~acl=/*~hmac=..."
```

管道自动完成：爬虫 → 音频下载 → Whisper 对齐 → Sudachi 分词 → ZhipuAI 翻译 → 部署到 App

## 数据格式

### raw.json（爬虫原始数据）

- `id`: 文章 ID
- `title`: 标题（带假名注音）
- `clean_title`: 网页原始纯净标题（不含假名注音）
- `time`: 发布时间
- `audio_uri`: 音频相对路径
- `sentences`: 句子数组（按句号拆分，每句带 `[假名]` 注音）

### processed.json（处理后数据）

- 与 raw.json 句子数量严格一致
- 每句含 `start_ms` / `end_ms`（来自 aligned.json）
- 每句含 `words` 数组（Sudachi 分词结果 + ruby_text 注音 + normalized_form）

## 注意事项

- 必须安装 `ffmpeg`（Mac: `brew install ffmpeg`）
- hdnts Token 有效期约 30 分钟，获取后需尽快使用
- DNS 问题详见 `HOW_TO_GET_TOKEN.md` 底部
