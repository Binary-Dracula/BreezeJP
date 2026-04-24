---
name: furigana
description: 为日语文本生成精准的振假名（Ruby / Furigana）注音。Use when: 给汉字加注音、生成振假名、Furigana 处理、ruby 注音。
---

# 振假名生成器

使用 Fugashi + UniDic-lite 形态分析器，为日语文本生成精准的振假名注音，严格遵守送假名规则，不依赖 LLM。

## 注音格式规则

1. 格式始终为 `漢字[ふりがな]`
2. 纯平假名 / 纯片假名不加注音括号
3. **送假名必须保留在括号外**：
   - ✅ `新[あたら]しい`、`食[た]べる`、`取[と]り入[い]れる`
   - ❌ `新しい[あたらしい]`（禁止）、`食べる[たべる]`（禁止）

## 重要：禁止用 LLM 生成振假名

LLM 频繁幻觉，无法稳定遵守送假名边界规则，会产生大量错误注音。**请始终使用本 skill 的脚本。**

## 使用方式

```bash
# 环境准备（只需一次）
pip install fugashi unidic-lite jaconv

# 单条文本注音
python .agents/skills/furigana/scripts/generate_ruby.py "日本語の文章を入力してください"

# 从 stdin 批量处理（每行一句，输出到 stdout）
echo -e "新しい朝\n食べる" | python .agents/skills/furigana/scripts/generate_ruby.py
```

## Python API

在其他脚本中直接调用 `generate_ruby()` 函数：

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(".agents/skills/furigana/scripts").resolve()))
from generate_ruby import generate_ruby

print(generate_ruby("新しい朝が来た"))
# → 新[あたら]しい朝[あさ]が来[き]た
```
