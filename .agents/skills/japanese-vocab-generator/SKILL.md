---
name: japanese-vocab-generator
description: "Generate structured Japanese vocabulary JSON data via Gemini API. Use when: creating word data, building vocab database, batch generating 单词数据, adding new Japanese words to the app."
argument-hint: "Provide path to word list file, e.g. files/单词生成器/单词源/n3_verbs.txt"
---

# Japanese Vocabulary Data Generator

批量生成结构化日语单词 JSON 数据，通过 Gemini API 产出包含 9 大维度的详尽词条信息，供 BreezeJP App 使用。

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
   # 临时设置（当前终端会话有效）
   export GEMINI_API_KEY="你的密钥"

   # 或写入 ~/.zshrc 永久生效
   echo 'export GEMINI_API_KEY="你的密钥"' >> ~/.zshrc
   ```

   密钥获取: https://aistudio.google.com/apikey

## Free Tier Limits (Gemini)

脚本已根据免费层配额进行优化。每次执行前会自动检查：

| 限制             | 值   | 脚本策略                        |
| ---------------- | ---- | ------------------------------- |
| RPM (请求/分钟)  | 15   | 批大小=3，间隔=5.5s → 约11 RPM  |
| TPM (Token/分钟) | 250K | 每请求≈8250 tokens → 约123K/min |
| RPD (请求/天)    | 500  | **最关键**，单日最多 1500 词    |

⚠️ **关键限制**：每日最多处理 ~1450 个单词（500 请求 × 3 词/批）。超过此数字需要分多天处理。

## Directory Structure

```
files/单词生成器/
├── 单词源/          ← 输入文件放这里（纯文本，逗号分隔的日语单词）
└── 输出结果/        ← 生成的 JSON 自动保存在这里
```

## Procedure

### Step 1: 准备单词源文件

在 `files/单词生成器/单词源/` 下新建一个文本文件，文件名自定义（如 `n3_verbs.txt`），内容为英文逗号分隔的日语单词：

```
間に合う,適当,妥協,把握,皮肉,貢献
```

- 支持换行（换行等同于逗号）
- 文件名将作为输出文件的前缀

如果用户没有提供文件，询问：

- 要处理哪个单词源文件？
- 或者用户想新建文件？帮助创建后再运行

### Step 2: 运行生成脚本

使用 skill 内置的 [生成脚本](./scripts/generate_vocab.py) 批量生成：

```bash
cd /Users/summer/work/money/breeze_jp
source .venv/bin/activate
python .agents/skills/japanese-vocab-generator/scripts/generate_vocab.py \
  --input files/单词生成器/单词源/n3_verbs.txt
```

**关键参数：**

- `--input`：必填，单词源文件路径（相对项目根目录或绝对路径）
- 脚本每批处理 5 个单词，批次间自动等待 4.5 秒（Gemini API 频率限制）
- 使用模型：`gemini-3.1-flash-lite-preview`，temperature=0.2

### Step 3: 确认输出

脚本运行完成后，JSON 文件自动保存至：

```
files/单词生成器/输出结果/{输入文件名}_{timestamp_ms}.json
```

例如输入文件为 `n3_verbs.txt`，输出为 `n3_verbs_1743000000000.json`。

检查输出文件：

1. 确认文件已生成且非空
2. 验证 JSON 格式正确
3. 抽查 1-2 个词条的完整性

### Step 4: 质量验证（可选）

如果用户要求验证数据质量，检查以下要点：

- 所有日文汉字是否标注了 `[假名]` ruby
- 动词/形容词的变形（`4_conjugations`）是否完整
- 例句（`6_example_sentences`）是否包含 3 个等级
- 近义词区别说明（`7_synonyms_and_antonyms`）是否详细

## Output JSON Structure

每个单词生成包含 9 个维度的 JSON 对象：

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

## Ruby 标注规则

输出 JSON 中所有日文汉字必须使用 `[假名]` 格式标注：

- 连续汉字写在一起：`一生懸命[いっしょうけんめい]`
- 带送假名的动词分开：`気[き]づく`
- 纯假名不标注

## Notes

- 每次运行会在文件名中附加毫秒时间戳，不会覆盖已有文件
- 如果某批次 API 调用失败，脚本会自动重试最多 3 次
- 免费 API 额度下，每分钟约可处理 75 个单词（15 RPM × 5 词/批）
