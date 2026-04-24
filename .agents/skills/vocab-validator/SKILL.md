---
name: vocab-validator
description: "校验 AI 生成的日语单词数据格式和完整性。Use when: 校验数据、检查生成结果、验证 JSON 结构。"
---

# 单词数据校验器

校验 AI 生成的单词数据文件格式、字段完整性、类型正确性和音频存在性。
是上传到生产环境前的质量关卡。

## 数据流水线位置

```
[vocab-scraper] 抓取  →  [vocab-generator] AI 生成  →  [本 Skill] 校验  →  [vocab-uploader] 上传
```

## 使用方式

```bash
source .venv/bin/activate

python .agents/skills/vocab-validator/scripts/validate.py \
  --book-name "新标日初级上册"
```

## 校验项目

| 类别 | 检查项                                              | 级别  |
| ---- | --------------------------------------------------- | ----- |
| 结构 | 顶层业务字段 + \_source_meta                        | ERROR |
| 必填 | word 非空；reading 仅在 word 含非假名字符时必填     | ERROR |
| 类型 | 每个字段类型匹配 Schema                             | ERROR |
| 枚举 | jlpt_level, part_of_speech, transitivity 在枚举值内 | WARN  |
| 活用 | conjugation 仅允许动词系词条保留；其余应为 null     | WARN  |
| 音频 | moji_word_id 对应的 mp3 存在                        | WARN  |
| 覆盖 | AI 输出 vs MOJi 源的词数一致性                      | WARN  |
| 重复 | word+reading 重复检测                               | WARN  |

## 退出码

- `0`: 全部通过（无 ERROR）
- `1`: 存在 ERROR（必填字段缺失、类型错误等）
- `2`: 仅有 WARN（建议修复但不阻断上传）
