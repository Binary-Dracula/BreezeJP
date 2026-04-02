---
name: japanese-ruby
description: A deterministic contextual tool to convert plain Japanese text into precise Ruby (Furigana) annotated strings using Fugashi and UniDic-lite, strictly adhering to Okurigana rules.
---

# Japanese Ruby Generator

This skill provides a programmatic, highly accurate, context-aware approach for converting Japanese text into a Ruby-annotated format. The formatting strictly separates Kanji roots from their Okurigana (送假名) suffixes. It avoids the AI hallucinations common with LLMs by using the industry-leading morphological analyzer `Fugashi` paired with `UniDic`.

## Core Rules

1. **Format Check**: The format is always `Kanji[furigana]`.
2. **Kana Exclusion**: Pure Hiragana or Katakana words NEVER get furigana brackets.
3. **Okurigana Preservation**: If a word has Okurigana, the bracket must ONLY wrap the Kanji.
   - ✅ Correct: `新[あたら]しい`
   - ✅ Correct: `食[た]べる`
   - ✅ Correct: `取[と]り入[い]れる`
   - ❌ Incorrect: `新しい[あたらしい]`
   - ❌ Incorrect: `食べる[たべる]`

## How to use this skill

If you are asked to generate Ruby annotations/Furigana for Japanese sentences in this project:

**DO NOT USE LARGE LANGUAGE MODELS FOR THIS TASK.** LLMs repeatedly hallucinate and frequently fail the strict Okurigana boundaries required by this project's UI.

Instead, execute the provided Python script located in this skill folder:
`scripts/generate_ruby.py`

### Python API Usage

You can use the script programmatically by invoking the `generate_ruby` function from the script, or you can run it from the command line depending on your needs.

#### Requirements

Before running the script, ensure the python environment has `fugashi`, `unidic-lite`, and `jaconv` installed:

```bash
pip install fugashi unidic-lite jaconv
```

#### Code Snippet

The core algorithm uses `fugashi` with `unidic-lite` to resolve complex contextual readings, combined with an exact string matching loop to isolate the Kanji stem from its Hiragana suffix (Okurigana). It natively translates Katakana results to Hiragana.

```python
import re
import fugashi
import jaconv
from functools import lru_cache

tagger = fugashi.Tagger()

@lru_cache(maxsize=10000)
def generate_ruby(text):
    if not text:
        return ""

    out = []

    for word in tagger(text):
        orig = word.surface

        if not re.search(r'[\u4e00-\u9fff]', orig):
            out.append(orig)
            continue

        kana = getattr(word.feature, 'kana', None)
        if not kana:
            out.append(orig)
            continue

        hira = jaconv.kata2hira(kana)
        orig_len, hira_len = len(orig), len(hira)

        suffix = ""
        i = 1
        while i <= orig_len and i <= hira_len:
            if orig[-i] == hira[-i]:
                suffix = orig[-i] + suffix
                i += 1
            else:
                break

        prefix = ""
        j, hira_start, orig_start = 0, 0, 0
        while j < (orig_len - len(suffix)) and j < (hira_len - len(suffix)):
            if orig[j] == hira[j]:
                prefix += orig[j]
                j += 1
                hira_start += 1
                orig_start += 1
            else:
                break

        kanji_part = orig[orig_start : orig_len - len(suffix)]
        ruby_part = hira[hira_start : hira_len - len(suffix)]

        if kanji_part and ruby_part and kanji_part != ruby_part:
            out.append(f"{prefix}{kanji_part}[{ruby_part}]{suffix}")
        else:
            out.append(orig)

    return "".join(out)
```
