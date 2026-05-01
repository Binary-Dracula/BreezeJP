---
name: vocab-generator
description: "通过 Gemini AI 批量生成结构化日语单词数据（9 维度）。Use when: AI 生成单词数据、丰富词汇信息、批量生成词条。"
argument-hint: "指定 --book-name 和 --book-title，如: --book-name 新标日初级上册 --book-title '新标准日本语初级上册'"
---

# AI 单词数据生成器 (v4)

通过 Gemini API 批量生成结构化日语单词 JSON 数据（不再包含汉字拆解维度），包含释义、语法、活用、例句等完整信息。

## 数据流水线位置

```
[vocab-scraper] 抓取  →  [本 Skill] AI 生成  →  [vocab-validator] 校验  →  [vocab-uploader] 上传
data/vocab/sources/        data/vocab/generated/        (校验报告)            Supabase + R2
```

## 前置条件

1. Python 虚拟环境已激活（`.venv`）
2. `pip install google-genai`
3. `.env` 中配置:
   ```
   GEMINI_API_KEY=your_api_key
   SUPABASE_SERVICE_KEY=your_key  # 可选，用于云端查重
   ```

## 模型与限流

- **模型**: `gemini-3.1-flash-lite-preview`（Free Tier RPD=500）
- 所有配置集中在 `_vocab_common/constants.py`，generate.py 不再有本地常量

| 参数                       | 值                            | 说明                            |
| -------------------------- | ----------------------------- | ------------------------------- |
| `GEMINI_MODEL`             | gemini-3.1-flash-lite-preview | 500 RPD 免费额度                |
| `GEMINI_BATCH_SIZE`        | 5                             | 每批 5 词，防止输出截断         |
| `GEMINI_MAX_OUTPUT_TOKENS` | 40960                         | 充足的输出空间（5 词 × 9 维度） |
| `GEMINI_RPM`               | 15                            | 控制在 ≈11 RPM                  |
| `GEMINI_TPM`               | 250K                          | ≈23K/min（安全）                |
| `GEMINI_RPD`               | 450                           | 主动限流，低于 500 留缓冲       |
| `GEMINI_WAIT_BETWEEN`      | 5.5s                          | 请求间隔                        |

- RPD 耗尽 → 自动保存进度并退出，提示明天用 `--resume` 继续
- 遇到 429 → 立即保存退出（不重试）
- 遇到 503 → 指数退避重试，最多 10 次（15s、2×递增，上限 300s）

## 使用方式

```bash
cd /path/to/breeze_jp
source .venv/bin/activate

# 首次生成
python .agents/skills/vocab-generator/scripts/generate.py \
  --book-name "新标日初级上册" \
  --book-title "新标准日本语初级上册"

# 断点续传
python .agents/skills/vocab-generator/scripts/generate.py \
  --book-name "新标日初级上册" \
  --book-title "新标准日本语初级上册" \
  --resume

# 重试失败词条
python .agents/skills/vocab-generator/scripts/generate.py \
  --book-name "新标日初级上册" \
  --book-title "新标准日本语初级上册" \
  --resume --retry-failed

# 跳过云端查重
python .agents/skills/vocab-generator/scripts/generate.py \
  --book-name "新标日初级上册" \
  --book-title "新标准日本语初级上册" \
  --skip-cloud-check
```

## 输出

输出文件: `data/vocab/generated/{book_name}.json`

结构:

```json
{
  "_meta": {
    "book_name": "新标日初级上册",
    "book_title": "新标准日本语初级上册",
    "book_id": "uuid",
    "total_words": 1401, "version": "4.0"
  },
  "words": [
    {
      "_word_id": "uuid",
      "_lesson": {"id": "uuid", "number": 1, "title": "第1课"},
      "_sort_order": 0,
      "_book_sort_order": 0,
      "1_basic_info": {...},
      "2_meanings_and_nuance": [...],
      ...
      "_source_meta": {"moji_word_id": "...", "generation_status": "SUCCESS"}
    }
  ]
}
```

## v4 架构要点

1. **Prompt 精简**: system prompt 从 ~150 行缩减到 ~15 行，JSON 结构完全由 `response_schema` 强制约束，prompt 只关注内容质量规则
2. **Batch 缩小**: 10 → 5 词/批，杜绝输出截断（原 v3 的 8192 token 不够 10 词的 9 维度数据）
3. **Token 充裕**: `max_output_tokens` 从 8192 → 40960，给足输出空间
4. **截断检测**: 检查 `finish_reason`，TRUNCATED 时自动重试
5. **Ruby 正则增强**: 支持汉字+假名混合标注（如 `お姉さん[おねえさん]`），不再只匹配纯汉字块
6. **常量集中管理**: 所有配置从 `_vocab_common/constants.py` 导入，generate.py 无本地常量

## 硬约束规则（v4）

- 使用 Gemini `response_schema` 强制 JSON 结构，结合精简 prompt 控制内容质量
- 返回必须是与输入批次同长度的 JSON 数组，否则该批次重试
- `jlpt_level` 仅允许 `N5/N4/N3/N2/N1/N/A`，不合法值强制归一为 `N/A`
- `transitivity` 仅允许 `自动词/他动词/null`
- `part_of_speech` 只保留受控枚举词性 token；无有效 token 视为不合规
- `pitch_accent` 仅允许数字或 `数字/数字` 形式，不合法值归一为 `null`
- 2-9 维度全部执行结构清洗：仅保留合法类型与合法字段，非法子项直接剔除
- 落盘前执行严格校验：词形、词性、JLPT、释义、例句等关键字段不满足即判定失败；`reading` 仅在 `word` 含非假名字符时要求非空
- 每批最多重试 5 次（v3 为 10 次），失败后标记 FAILED_SKIP 继续下一批

## Ruby 规则（严格）

- 除 `4_conjugations` 外，所有日语句子/短句字段（如例句 `japanese`、助词搭配 `pattern`、固定搭配 `phrase`）若含汉字，必须使用 `漢字[かんじ]` 格式标注
- 支持汉字+假名混合词的标注（如 `お姉[ね]さん`、`食[た]べる`）
- 若存在未加 ruby 的汉字，该子项会被清洗丢弃；导致关键字段为空时该词条会被判定失败并触发批次重试
- `4_conjugations` 明确禁止 ruby，统一输出纯词形（例如 `新しい`，不是 `新[あたら]しい`）
- 如果 `word` 本身全是假名（平假名或片假名），`reading` 必须输出空字符串 `""`，不要重复 `word`
- `4_conjugations` 只保留带动词性质的词；名词、副词、惯用句等非动词词性统一输出 `null`
