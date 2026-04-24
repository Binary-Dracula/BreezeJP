---
name: nhk-easy-news
description: "抓取 NHK Easy News 新闻、音频、时间轴和分词结果。Use when: 抓取 NHK 新闻、更新每日新闻数据、运行 NHK Easy News 数据管道。"
---

# NHK Easy News 数据管道

运行 `.agents/skills/nhk-easy-news/pipeline/` 里的整套 NHK 新闻抓取和处理工具，产出可供 App 使用的新闻数据。

## 能做什么

- 抓取 NHK Easy News 最新文章
- 下载新闻音频
- 生成音频对齐时间轴
- 进行 Sudachi / Kuromoji 分词
- 翻译句子并转换为 App 可消费格式
- 可选上传到 Supabase + R2

## 前置条件

1. 已准备 `.agents/skills/nhk-easy-news/pipeline/venv`
2. 已安装 `ffmpeg`
3. 如需音频下载，需要有效的 `hdnts` token
4. 如需上传后端，需要 `.env` 中已有 `SUPABASE_SERVICE_KEY`

## 使用方式

```bash
cd /path/to/breeze_jp

# 交互模式
python .agents/skills/nhk-easy-news/scripts/run.py

# 直接运行整套 NHK 管道
python .agents/skills/nhk-easy-news/scripts/run.py \
  --hdnts "exp=...~acl=/*~hmac=..." \
  --tokenizer sudachi \
  --sudachi-mode B

# 跑完后顺手上传到后端
python .agents/skills/nhk-easy-news/scripts/run.py \
  --hdnts "exp=...~acl=/*~hmac=..." \
  --upload
```

## 输出位置

- `.agents/skills/nhk-easy-news/pipeline/data/{article_id}/`：原始数据、中间数据、对齐结果
- `assets/mock/`：转换后的 App mock 数据与音频副本

## 相关文件

- `.agents/skills/nhk-easy-news/pipeline/scripts/run_pipeline.sh`：整条处理流水线
- `.agents/skills/nhk-easy-news/pipeline/scripts/nhk_scraper.py`：新闻抓取 + 音频下载
- `.agents/skills/nhk-easy-news/pipeline/scripts/upload_to_backend.py`：上传 Supabase + R2
- `.agents/skills/nhk-easy-news/pipeline/HOW_TO_GET_TOKEN.md`：如何手动获取 `hdnts` token

## 说明

这个 Skill 封装的是现有 NHK 工具，不重复实现底层抓取逻辑；主要作用是统一入口，减少以后手动进入 `.agents/skills/nhk-easy-news/pipeline/` 执行的成本。
