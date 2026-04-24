#!/usr/bin/env python3
"""
单词数据校验器 (v3.0)
====================
校验 AI 生成的词条 JSON 数据格式、字段完整性和音频文件存在性。

退出码: 0=通过, 1=有ERROR, 2=仅WARN
"""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import (
    SOURCES_DIR, GENERATED_DIR,
    JLPT_LEVELS, TRANSITIVITY_VALUES, PARTS_OF_SPEECH,
    CONJUGATION_KEYS, NO_CONJUGATION_MARKERS,
)

REQUIRED_TOP_KEYS = [
    "1_basic_info", "2_meanings_and_nuance", "3_critical_grammar_rules",
    "4_conjugations", "6_example_sentences",
    "7_synonyms_and_antonyms", "8_collocations_and_phrases",
    "9_common_mistakes_and_usage_notes", "_source_meta",
]

RUBY_PATTERN = re.compile(r"[一-龯々][^\s\[]*\[[^\]]+\]")
KANA_ONLY_RE = re.compile(r"[\u3040-\u309F\u30A0-\u30FFー・\s]+")

VERB_POS_MARKERS = (
    "动词", "動詞", "自动词", "自動詞", "他动词", "他動詞",
    "五段动词", "五段動詞", "一段动词", "一段動詞", "サ变", "サ変",
)

COPULA_FORM_MARKERS = (
    "です", "でした", "ではない", "じゃない", "である", "だった",
)


class ValidationReport:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.stats = Counter()

    def error(self, index, msg):
        self.errors.append(f"  [ERROR] #{index}: {msg}")
        self.stats["errors"] += 1

    def warn(self, index, msg):
        self.warnings.append(f"  [WARN]  #{index}: {msg}")
        self.stats["warnings"] += 1

    def print_report(self):
        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for e in self.errors[:50]:
                print(e)
            if len(self.errors) > 50:
                print(f"  ... 还有 {len(self.errors) - 50} 条")

        if self.warnings:
            print(f"\n⚠️ WARNINGS ({len(self.warnings)}):")
            for w in self.warnings[:50]:
                print(w)
            if len(self.warnings) > 50:
                print(f"  ... 还有 {len(self.warnings) - 50} 条")

    @property
    def exit_code(self):
        if self.errors:
            return 1
        if self.warnings:
            return 2
        return 0


def flatten_moji_words(items):
    words = []
    for item in items:
        if item.get("type") == "folder":
            words.extend(flatten_moji_words(item.get("items", [])))
        elif item.get("type") == "word":
            words.append(item)
    return words


def validate_entry(index, entry, report: ValidationReport, audio_dir: Path):
    """校验单个词条。"""
    if not isinstance(entry, dict):
        report.error(index, f"词条类型错误: {type(entry).__name__}")
        return

    # 元数据字段（v3.0 新增）
    word_id = entry.get("_word_id")
    lesson = entry.get("_lesson")

    # 顶层 9 维度
    for key in REQUIRED_TOP_KEYS:
        if key not in entry:
            report.error(index, f"缺少顶层字段: {key}")

    # _source_meta
    meta = entry.get("_source_meta", {})
    if not isinstance(meta, dict):
        report.error(index, f"_source_meta 类型错误")
        return

    status = meta.get("generation_status", "")
    if status in ("CLOUD_REFERENCE", "FAILED_SKIP"):
        report.stats[f"status_{status}"] += 1
        if status == "FAILED_SKIP":
            report.warn(index, f"生成失败的词条: {meta.get('word_text', '?')}")
        return  # 占位词条不做深度校验

    moji_id = meta.get("moji_word_id", "")

    # 1_basic_info
    basic = entry.get("1_basic_info", {})
    if not isinstance(basic, dict):
        report.error(index, f"1_basic_info 类型错误: {type(basic).__name__}")
        return

    word = basic.get("word", "")
    reading = basic.get("reading", "")
    pos = str(basic.get("part_of_speech", "") or "").strip()
    if not word:
        report.error(index, "word 为空")
    if not reading and not KANA_ONLY_RE.fullmatch(str(word or "")):
        report.error(index, "reading 为空")
    if not pos:
        report.error(index, "part_of_speech 为空")
    else:
        invalid_tokens = [token for token in pos.split("/") if token and token not in PARTS_OF_SPEECH]
        if invalid_tokens:
            report.error(index, f"part_of_speech 含非法枚举值: {invalid_tokens}")

    # 枚举校验
    jlpt = basic.get("jlpt_level", "")
    if jlpt and jlpt not in JLPT_LEVELS:
        report.warn(index, f"jlpt_level 不在枚举中: '{jlpt}'")

    transitivity = basic.get("transitivity")
    if transitivity is not None and transitivity not in TRANSITIVITY_VALUES:
        report.warn(index, f"transitivity 不在枚举中: '{transitivity}'")

    pitch = basic.get("pitch_accent")
    if pitch is not None and pitch != "":
        if not re.fullmatch(r"\d+(/\d+)*", str(pitch)):
            report.warn(index, f"pitch_accent 格式异常: '{pitch}'")

    # 2_meanings
    meanings = entry.get("2_meanings_and_nuance", [])
    if not isinstance(meanings, list):
        report.error(index, f"2_meanings 类型错误: {type(meanings).__name__}")
    elif not meanings:
        report.warn(index, "释义为空")
    else:
        for mi, m in enumerate(meanings):
            if not isinstance(m, dict) or "definition" not in m:
                report.error(index, f"释义 #{mi} 结构错误")

    # 3_grammar
    grammar = entry.get("3_critical_grammar_rules", {})
    if not isinstance(grammar, dict):
        report.error(index, f"3_grammar 类型错误")

    # 4_conjugations
    conj = entry.get("4_conjugations", {})
    if not isinstance(conj, dict):
        report.error(index, f"4_conjugations 类型错误")
    else:
        meaningful_conjugations = []
        for key in CONJUGATION_KEYS:
            if key not in conj:
                report.warn(index, f"缺少活用键: {key}")
            else:
                val = conj[key]
                if val is not None and isinstance(val, str):
                    if val.lower() in NO_CONJUGATION_MARKERS:
                        report.warn(index, f"活用 {key} 含占位文本: '{val}'")
                    elif val.strip():
                        meaningful_conjugations.append((key, val.strip()))

        if meaningful_conjugations and _looks_suspicious_for_conjugation(pos, meaningful_conjugations):
            report.warn(
                index,
                f"词性 '{pos}' 出现可疑活用，请人工复核: "
                + ", ".join(f"{key}={value}" for key, value in meaningful_conjugations[:3]),
            )

        for key, value in meaningful_conjugations:
            if RUBY_PATTERN.search(value):
                report.stats["conjugation_ruby_entries"] += 1

    # 6_examples
    examples = entry.get("6_example_sentences", [])
    if not isinstance(examples, list):
        report.error(index, f"6_examples 类型错误")
    elif not examples:
        report.warn(index, "例句为空")
    else:
        for ei, ex in enumerate(examples):
            if not isinstance(ex, dict) or "japanese" not in ex or "chinese" not in ex:
                report.error(index, f"例句 #{ei} 结构错误")
            elif len(ex.keys() - {"japanese", "chinese"}) > 0:
                extra = ex.keys() - {"japanese", "chinese"}
                report.warn(index, f"例句 #{ei} 含多余字段: {extra}")

    # 7_synonyms
    syn = entry.get("7_synonyms_and_antonyms", {})
    if not isinstance(syn, dict):
        report.error(index, f"7_synonyms 类型错误")
    elif "synonyms" not in syn or "antonyms" not in syn:
        report.error(index, "7_synonyms 缺 synonyms/antonyms 键")

    # 8_collocations
    coll = entry.get("8_collocations_and_phrases", [])
    if not isinstance(coll, list):
        report.error(index, f"8_collocations 类型错误")

    # 9_mistakes
    mistakes = entry.get("9_common_mistakes_and_usage_notes", [])
    if not isinstance(mistakes, list):
        report.error(index, f"9_mistakes 类型错误")

    # 音频检查
    if moji_id and audio_dir.exists():
        audio_file = audio_dir / f"{moji_id}.mp3"
        if not audio_file.exists():
            report.warn(index, f"音频缺失: {moji_id}.mp3")

    report.stats["validated"] += 1


def _looks_suspicious_for_conjugation(pos: str, meaningful_conjugations):
    if not pos:
        return False

    lowered_pos = pos.lower()
    if any(marker.lower() in lowered_pos for marker in VERB_POS_MARKERS):
        return False

    joined_forms = " ".join(value for _, value in meaningful_conjugations)
    if any(marker in joined_forms for marker in COPULA_FORM_MARKERS):
        return False

    return True


def main():
    parser = argparse.ArgumentParser(description="单词数据校验器")
    parser.add_argument("--book-name", required=True, help="辞书名")
    args = parser.parse_args()

    project_root = config.PROJECT_ROOT
    source_dir = project_root / SOURCES_DIR / args.book_name
    generated_file = project_root / GENERATED_DIR / f"{args.book_name}.json"
    words_json = source_dir / "words.json"
    audio_dir = source_dir / "audios"

    if not generated_file.exists():
        print(f"❌ 找不到生成文件: {generated_file}")
        sys.exit(1)

    with open(generated_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    meta = data.get("_meta", {})
    words = data.get("words", [])

    print(f"\n📋 校验: {args.book_name}")
    print(f"   辞书: {meta.get('book_title', '?')}")
    print(f"   词条数: {len(words)}")
    print(f"   版本: {meta.get('version', '?')}")

    # MOJi 源对比
    moji_words = []
    if words_json.exists():
        with open(words_json, "r", encoding="utf-8") as f:
            moji_tree = json.load(f)
        moji_words = flatten_moji_words(moji_tree)
        moji_ids = set(str(w.get("wordId", "")) for w in moji_words if w.get("wordId"))
        ai_moji_ids = set()
        for w in words:
            mid = w.get("_source_meta", {}).get("moji_word_id", "")
            if mid:
                ai_moji_ids.add(mid)
        missing_in_ai = moji_ids - ai_moji_ids
        extra_in_ai = ai_moji_ids - moji_ids
        print(f"   MOJi 源词数: {len(moji_words)} (唯一 ID: {len(moji_ids)})")
        if missing_in_ai:
            print(f"   ⚠️ AI 缺失 MOJi 词: {len(missing_in_ai)}")
        if extra_in_ai:
            print(f"   ⚠️ AI 多出词: {len(extra_in_ai)}")

    # 逐条校验
    report = ValidationReport()
    word_reading_counter = Counter()
    word_id_counter = Counter()

    for idx, entry in enumerate(words):
        validate_entry(idx, entry, report, audio_dir)
        basic = entry.get("1_basic_info", {}) if isinstance(entry, dict) else {}
        key = f"{basic.get('word', '')}:{basic.get('reading', '')}"
        word_reading_counter[key] += 1
        wid = entry.get("_word_id", "")
        if wid:
            word_id_counter[wid] += 1

    # 重复检测
    duplicates = {k: v for k, v in word_reading_counter.items() if v > 1 and k != ":"}
    if duplicates:
        for k, v in duplicates.items():
            report.warn(-1, f"重复 word:reading → {k} ({v} 次)")

    id_dups = {k: v for k, v in word_id_counter.items() if v > 1 and k}
    if id_dups:
        for k, v in id_dups.items():
            report.warn(-1, f"重复 _word_id → {k} ({v} 次)")

    # 报告
    print(f"\n{'='*60}")
    print(f"  已校验:     {report.stats.get('validated', 0)}")
    print(f"  SUCCESS:    {report.stats.get('validated', 0)}")
    print(f"  CLOUD_REF:  {report.stats.get('status_CLOUD_REFERENCE', 0)}")
    print(f"  FAILED:     {report.stats.get('status_FAILED_SKIP', 0)}")
    print(f"  重复:       {len(duplicates)}")
    print(f"  ERRORS:     {len(report.errors)}")
    print(f"  WARNINGS:   {len(report.warnings)}")
    print(f"{'='*60}")

    report.print_report()

    code = report.exit_code
    if code == 0:
        print(f"\n✅ 校验通过!")
    elif code == 2:
        print(f"\n⚠️ 校验通过（有 {len(report.warnings)} 条警告）")
    else:
        print(f"\n❌ 校验失败（{len(report.errors)} 条错误）")

    sys.exit(code)


if __name__ == "__main__":
    main()
