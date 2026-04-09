---
name: japanese-vocab-generator
description: "Generate structured Japanese vocabulary JSON data via Gemini API. Use when: creating word data, building vocab database, batch generating 单词数据, adding new Japanese words to the app."
argument-hint: "Provide path to word list file, e.g. files/单词生成器/单词源/n3_verbs.txt or files/单词生成器/单词源/新标日初级下册/words.json"
---

# Japanese Vocabulary Data Generator

批量生成结构化日语单词 JSON 数据，通过 Gemini API 产出包含 9 大维度的详尽词条信息，供 BreezeJP App 使用。

## 数据流水线位置

```
[mojidict_scraper] MOJi 抓取    →  [本 Skill] AI 生成             →  upload_words.py 上传
files/单词生成器/单词源/              files/单词生成器/输出结果/          Supabase + R2
  ├── {PROJECT}/words.json            └── {PROJECT}_{ts}.json
  └── {PROJECT}/audios/                   (含 _source_meta 溯源)
```

## When to Use

- 需要为 App 添加新的单词数据
- 批量生成日语词汇的结构化 JSON
- 用户说「生成单词数据」「做单词数据」「添加词汇」等

## Prerequisites

1. Python 虚拟环境已激活（项目根目录 `.venv`）
2. `google-generativeai` 已安装：
   ```bash
   pip install -U google-generativeai
   ```
3. 环境变量 `GEMINI_API_KEY` 已设置：
   ```bash
   export GEMINI_API_KEY="你的密钥"
   ```
   密钥获取: https://aistudio.google.com/apikey

## Free Tier Limits (Gemini)

| 限制             | 值   | 脚本策略                        |
| ---------------- | ---- | ------------------------------- |
| RPM (请求/分钟)  | 15   | 批大小=3，间隔=5.5s → 约11 RPM  |
| TPM (Token/分钟) | 250K | 每请求≈8250 tokens → 约123K/min |
| RPD (请求/天)    | 500  | **最关键**，单日最多 1500 词    |

⚠️ **关键限制**：每日最多处理 ~1450 个单词（500 请求 × 3 词/批）。超过此数字需要分多天处理。

## Directory Structure

```
files/单词生成器/
├── 单词源/                ← 输入文件放这里
│   ├── n3_verbs.txt      ← 纯文本格式（逗号分隔）
│   └── 新标日初级下册/    ← MOJi 抓取的项目（由 mojidict_scraper 生成）
│       ├── words.json    ← 树形词库数据
│       └── audios/       ← 配套音频 {wordId}.mp3
└── 输出结果/              ← 生成的 JSON 自动保存在这里
    └── 新标日初级下册_1743000000000.json
```

## Procedure

### Step 1: 准备单词源

**方式 A — 纯文本（手动）**：在 `files/单词生成器/单词源/` 下新建 `.txt` 文件：
```
間に合う,適当,妥協,把握,皮肉,貢献
```

**方式 B — MOJi 抓取（推荐）**：先用 `mojidict_scraper` skill 抓取，输出会自动存到 `files/单词生成器/单词源/{PROJECT_NAME}/words.json`。

### Step 2: 运行生成脚本

```bash
cd /Users/summer/work/money/breeze_jp
source .venv/bin/activate

# 方式 A：纯文本输入
python .agents/skills/japanese-vocab-generator/scripts/generate_vocab.py \
  --input files/单词生成器/单词源/n3_verbs.txt

# 方式 B：MOJi JSON 输入（自动提取单词 + 注入溯源信息）
python .agents/skills/japanese-vocab-generator/scripts/generate_vocab.py \
  --input files/单词生成器/单词源/新标日初级下册/words.json
```

**两种输入的区别**：
- `.txt` 输入：纯 AI 生成，输出不含 `_source_meta`
- `.json` 输入：自动从 MOJi 树形结构提取单词列表，输出中每个词条注入 `_source_meta` 字段（含 `moji_word_id`），用于后续 `upload_words.py` 追踪对应的 MOJi 音频文件

### Step 3: 确认输出

输出文件保存至：
```
files/单词生成器/输出结果/{输入名}_{timestamp_ms}.json
```
- `.txt` 输入 → 文件名前缀为输入文件名（如 `n3_verbs_xxx.json`）
- `.json` 输入 → 文件名前缀为 PROJECT_NAME（如 `新标日初级下册_xxx.json`）

检查输出文件：
1. 确认文件已生成且非空
2. 验证 JSON 格式正确
3. 抽查 1-2 个词条的完整性
4. 若为 MOJi 输入，确认 `_source_meta.moji_word_id` 已正确注入

### Step 4: 质量验证（可选）

- 所有日文汉字是否标注了 `[假名]` ruby
- 动词/形容词的变形（`4_conjugations`）是否完整
- 例句（`6_example_sentences`）是否包含 3 个等级
- 近义词区别说明是否详细

## Output JSON Structure

每个单词生成包含 9 个维度的 JSON 对象。当输入为 MOJi JSON 时，额外包含 `_source_meta` 溯源字段：

| 字段                                | 内容                                                       |
| ----------------------------------- | ---------------------------------------------------------- |
| `1_basic_info`                      | 单词、读音、罗马音、声调、JLPT等级、词性、自他动词         |
| `2_meanings_and_nuance`             | 多个中文释义 + 语感场景说明                                |
| `3_critical_grammar_rules`          | 常搭配助词及用法解释                                       |
| `4_conjugations`                    | 基本形、ます形、ない形、て形、た形、可能形、受身形、使役形 |
| `5_kanji_components`                | 每个汉字的音读、训读、核心本意                             |
| `6_example_sentences`               | 口语/礼貌体/敬语 三个等级的例句                            |
| `7_synonyms_and_antonyms`           | 近义词（含差异说明）+ 反义词                               |
| `8_collocations_and_phrases`        | 高频固定搭配                                               |
| `9_common_mistakes_and_usage_notes` | 中文母语者常犯错误及避坑说明                               |
| `_source_meta`（仅 MOJi 输入）       | `moji_word_id` + 原始读音/声调/释义，用于追踪音频          |

## Ruby 标注规则

输出 JSON 中所有日文汉字必须使用 `[假名]` 格式标注：
- 连续汉字写在一起：`一生懸命[いっしょうけんめい]`
- 带送假名的动词分开：`気[き]づく`
- 纯假名不标注

## Notes

- 每次运行会在文件名中附加毫秒时间戳，不会覆盖已有文件
- 如果某批次 API 调用失败，脚本会自动重试最多 3 次
- 免费 API 额度下，每分钟约可处理 75 个单词（15 RPM × 5 词/批）
- MOJi 输入时，溯源匹配会尝试去除 ruby 标注后进行模糊匹配
