---
name: mojidict_scraper
description: "Scrape full Japanese vocabulary collections from MOJiDict with recursive folder structure, handling authentication and automatic audio downloads."
---

# MOJiDict 数据抓取 (Skill)

项目专用的词库抓取工具，自动爬取合集目录结构并下载音频。输出到 `files/单词生成器/单词源/` 目录，与 `japanese-vocab-generator` skill 无缝衔接。

## 数据流水线位置

```
[本 Skill] MOJi 抓取           →  [japanese-vocab-generator] AI 生成  →  upload_words.py 上传
files/单词生成器/单词源/           files/单词生成器/输出结果/              Supabase + R2
  └── {PROJECT_NAME}/
      ├── words.json               └── {PROJECT_NAME}_{timestamp}.json
      └── audios/{wordId}.mp3
```

## 项目结构

*   **主程序**: `scripts/main.py` — 抓取词库 + 自动下载音频
*   **下载器**: `scripts/download.py` — 仅补抓缺失音频
*   **指南**: `resources/token_guide.md`

## 使用流程

### 1. 配置项目参数

修改 `scripts/main.py` 顶部的配置：
```python
USERNAME = "summer.work.001@gmail.com"  # MOJi 账号邮箱
PASSWORD = "your_password"              # 对应密码，脚本会自动获取 SessionToken

START_ID = "目标合集ID"           # MOJi 合集 FID
PROJECT_NAME = "nsh_junior_1"     # 自定义文件夹名，决定输出路径
DOWNLOAD_AUDIO = True             # 是否开启自动下载音频
```

### 2. 执行抓取

```bash
python3 .agents/skills/mojidict_scraper/scripts/main.py
```

### 3. 确认输出

抓取结果保存在 `files/单词生成器/单词源/{PROJECT_NAME}/`：
- `words.json` — 树形结构化词库（含 folder/word 嵌套、wordId、音频 URL）
- `audios/` — 所有 `{wordId}.mp3` 音频文件

### 4. 衔接 AI 生成

抓取完成后，直接用 `japanese-vocab-generator` skill 处理：
```bash
python .agents/skills/japanese-vocab-generator/scripts/generate_vocab.py \
  --input files/单词生成器/单词源/{PROJECT_NAME}/words.json
```

脚本会自动：
1. 从 `words.json` 提取所有单词
2. 通过 Gemini AI 生成 9 维度数据
3. 在输出 JSON 中注入 `_source_meta`（含 `moji_word_id`，用于追踪对应的音频文件）
4. 保存到 `files/单词生成器/输出结果/{PROJECT_NAME}_{timestamp}.json`

## 输出数据格式

### words.json 结构
```json
[
  {
    "type": "folder", "title": "第1课", "id": "xxx",
    "items": [
      {
        "type": "word", "word": "日本語", "reading": "にほんご",
        "accent": "0", "meaning": "日语",
        "audio": "https://oss.mojidict.com/...",
        "targetId": "xxx", "wordId": "abc123"
      }
    ]
  }
]
```

### 音频文件命名
`audios/{wordId}.mp3` — wordId 与 words.json 中的 `wordId` 字段一一对应。

## 注意事项

- **自动登录**：脚本现在内置了调用 `/parse/login` 自动获取 Token 的逻辑，无需再手动更新 `SESSION_TOKEN`。
- **断点续传**：下载音频时自动检测已存在文件并跳过
- **补抓音频**：如需单独补抓音频，修改 `download.py` 中的 `PROJECT_NAME` 后运行
