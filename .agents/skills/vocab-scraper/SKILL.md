---
name: vocab-scraper
description: "从 MOJi 辞书抓取日语单词数据和音频。Use when: 抓取 MOJi 数据、爬取辞书、下载单词音频。"
---

# MOJi 辞书数据抓取

从 MOJiDict 抓取完整的日语单词合集，输出结构化 JSON 和音频文件。是单词数据流水线的第一步。

## 数据流水线位置

```
[本 Skill] 抓取  →  [vocab-generator] AI 生成  →  [vocab-validator] 校验  →  [vocab-uploader] 上传
data/vocab/sources/     data/vocab/generated/       (校验报告)            Supabase + R2
```

## 前置条件

1. Python 虚拟环境已激活（`.venv`）
2. `.env` 中配置了 MOJi 账号:
   ```
   MOJI_USERNAME=your_email@example.com
   MOJI_PASSWORD=your_password
   ```

## 使用方式

```bash
cd /path/to/breeze_jp
source .venv/bin/activate

# 交互模式（脚本会询问辞书名和合集 ID）
python .agents/skills/vocab-scraper/scripts/scrape.py

# 命令行模式
python .agents/skills/vocab-scraper/scripts/scrape.py \
  --book-name "新标日初级上册" \
  --collection-id "FoIhGqBo87"
```

## 输出

抓取结果保存在 `data/vocab/sources/{book_name}/`:

- `words.json` — 树形结构化词库（含 folder/word 嵌套）
- `audios/{wordId}.mp3` — 单词音频文件

## 中级课次重排（同课合并）

对于中级上下册，MOJi 原始结构中同一课会拆成多个分段（如 `第25课-课文`、`第25课-会话`、`第25课-关联词语`）。

使用本 Skill 内置脚本可重排为统一结构：`单元 -> 课`，并把同课所有分段合并到同一个课节点中。

```bash
source .venv/bin/activate

# 覆盖重写 words.json（推荐）
python .agents/skills/vocab-scraper/scripts/normalize_words.py \
  --book-name "新标日中级上册" \
  --book-name "新标日中级下册"

# 非覆盖模式：输出 words.normalized.json
python .agents/skills/vocab-scraper/scripts/normalize_words.py \
  --book-name "新标日中级上册" \
  --no-in-place
```

脚本保证：

- 同一课的 `课文/会话/关联词语` 自动合并
- 单元按顺序排序（如 `第五单元`、`第六单元`...）
- 课按顺序排序（如 `第二十五课`、`第二十六课`...）
- 总词数不变（写回前后自动校验）

## 输出数据格式 (words.json)

```json
[
  {
    "type": "folder",
    "title": "第1课",
    "id": "xxx",
    "items": [
      {
        "type": "word",
        "word": "日本語",
        "reading": "にほんご",
        "accent": "0",
        "meaning": "日语",
        "audio": "https://oss.mojidict.com/...",
        "targetId": "xxx",
        "wordId": "abc123"
      }
    ]
  }
]
```

## 特性

- 自动登录获取 SessionToken（无需手动刷新）
- 指数退避重试（HTTP 错误自动重试 5 次）
- 音频下载带重试 + 文件完整性校验
- 断点续传：已下载的音频自动跳过
- 课序排序：自动按中文数字排序（第一课、第二课...）
