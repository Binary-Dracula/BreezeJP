---
name: vocab-uploader
description: "将校验通过的单词数据和音频上传到 Supabase 和 Cloudflare R2。Use when: 上传数据、同步后端、发布词汇。"
---

# 单词数据上传器

将 AI 生成并校验通过的单词数据批量上传到 Supabase（数据库）和 Cloudflare R2（音频存储）。

## 数据流水线位置

```
[vocab-scraper] 抓取  →  [vocab-generator] AI 生成  →  [vocab-validator] 校验  →  [本 Skill] 上传
                                                                                    Supabase + R2
```

## 前置条件

1. `.env` 中配置:
   ```
   SUPABASE_SERVICE_KEY=your_service_key
   CLOUDFLARE_API_TOKEN=your_token    # 可选，缺失时跳过音频上传
   ```
2. wrangler CLI 已安装 (`npm i -g wrangler`)
3. 数据已通过 vocab-validator 校验

## 使用方式

```bash
source .venv/bin/activate

# 预览模式（不实际写入）
python .agents/skills/vocab-uploader/scripts/upload.py \
  --book-name "新标日初级上册" \
  --dry-run

# 实际上传
python .agents/skills/vocab-uploader/scripts/upload.py \
  --book-name "新标日初级上册"

# 跳过校验直接上传
python .agents/skills/vocab-uploader/scripts/upload.py \
  --book-name "新标日初级上册" \
  --skip-validate

# 断点续传
python .agents/skills/vocab-uploader/scripts/upload.py \
  --book-name "新标日初级上册" \
  --resume
```

## 特性

- 上传前自动运行 vocab-validator（除非 --skip-validate）
- DB 使用事务性分阶段写入 + 验证
- 上传后从 Supabase 读回 count 校验
- R2 音频并发上传 (8 线程) + 重试 + 断点续传
- --dry-run 预览模式
- 主键冲突自动处理（UUID5 确定性）

## 已知问题与处理

### 源数据中存在重复 word_id（同一词在多课出现）

`make_uuid("word", ...)` 是确定性的，同一词不同 lesson 会产生相同 word_id。  
`map_rows` 用 `seen_map_ids` set 去重（已在 upload.py 中处理），避免同批次内 ON CONFLICT 报错。

### has_audio 更新用 PATCH 而非 UPSERT

更新 `words.has_audio` 时必须用 HTTP PATCH（`sb_patch_many`），不能用 `sb_upsert`。  
原因：UPSERT with merge-duplicates 对不存在的行会尝试 INSERT，缺少 NOT NULL 字段则报 23502。  
PATCH 对不存在的行静默跳过，不会触发 INSERT。

### R2 并发上传期间 Supabase SSL EOF

R2 使用 8 线程并发上传时，避免同时发出大量串行 Supabase HTTPS 请求（如逐词 PATCH）。  
使用 `sb_patch_many` 批量化（batch_size=100），将 2000+ 次连接缩减到 ~21 次。
