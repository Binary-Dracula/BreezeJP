#!/usr/bin/env python3
"""
日语单词 AI 数据生成器 (v4.0)
=============================
通过 Gemini API 批量生成 9 维度结构化词条数据。
v4: 精简 prompt, 依赖 response_schema 强制 JSON 结构, 增大 token 上限。
"""

import argparse
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import (
    SUPABASE_URL, SOURCES_DIR, GENERATED_DIR, CHECKPOINTS_DIR, LOGS_DIR,
    GEMINI_MODEL, GEMINI_RPM, GEMINI_TPM, GEMINI_RPD,
    GEMINI_BATCH_SIZE, GEMINI_WAIT_BETWEEN, GEMINI_MAX_OUTPUT_TOKENS,
    JLPT_LEVELS, PARTS_OF_SPEECH, TRANSITIVITY_VALUES,
    CONJUGATION_KEYS, POS_TOKEN_MAP, POS_SUBSTRING_MAP, POS_EXACT_MAP,
    NULL_STRINGS, NO_CONJUGATION_MARKERS, CIRCLED_DIGITS,
    POS_FALLBACK_BY_MOJI_ID,
    make_uuid,
)
from _vocab_common.rate_limiter import RateLimiter

import requests

# ============================================================
# Prompt (精简版，结构由 response_schema 强制)
# ============================================================

_POS_LIST = ", ".join(sorted(PARTS_OF_SPEECH))
_JLPT_LIST = ", ".join(sorted(JLPT_LEVELS))

SYSTEM_PROMPT = f"""你是精通中日双语的日语教育专家。根据输入的单词列表生成详细的词条数据。

核心规则:
1. 输出数组长度和顺序必须与输入完全一致。
2. word 字段必须与输入的 word 完全一致，不要改动。
3. reading 为全平假名；但如果 word 本身全是假名（含片假名），reading 必须返回空字符串；romaji 为罗马音。
4. pitch_accent: 纯数字如 "0"、"3"，多个用 "/" 分隔如 "0/3"，不确定时为 null。
5. jlpt_level 只能是: {_JLPT_LIST}
6. part_of_speech 用简体中文，复合词性用 "/" 分隔。常见值: {_POS_LIST}
7. transitivity: 动词填 "自动词" 或 "他动词"，非动词填 null。
8. 多义词必须给出多个释义。
9. 例句至少 2 条，日语句子中的汉字必须标注振假名: 漢字[かんじ]。每个汉字单独标注，不要把多个汉字包在一个 [] 里。
10. 4_conjugations 中的值禁止使用振假名标注，必须是纯词形。只有带动词性质的词保留活用，其余一律填 null。
11. 助词搭配 pattern、固定搭配 phrase 中的汉字也必须标注振假名。
12. nuance 没有内容时返回空字符串 ""。"""


def build_batch_prompt(batch_entries):
    payload = []
    for i, entry in enumerate(batch_entries, 1):
        sm = entry["source_meta"]
        payload.append({
            "index": i,
            "word": entry["word_text"],
            "reading": entry["reading"],
            "accent": sm.get("moji_accent"),
            "meaning_hint": (sm.get("moji_meaning") or "").strip(),
        })
    return (
        "根据以下输入数组，返回同长度同顺序的 JSON 数组:\n"
        + json.dumps(payload, ensure_ascii=False, indent=2)
    )


# ============================================================
# Gemini 结构化输出 Schema
# ============================================================

ITEM_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "1_basic_info": {
            "type": "OBJECT",
            "properties": {
                "word": {"type": "STRING"},
                "reading": {"type": "STRING"},
                "romaji": {"type": "STRING"},
                "pitch_accent": {"type": "STRING", "nullable": True},
                "jlpt_level": {"type": "STRING", "enum": sorted(JLPT_LEVELS)},
                "part_of_speech": {"type": "STRING"},
                "transitivity": {"type": "STRING", "nullable": True, "enum": sorted(TRANSITIVITY_VALUES)},
            },
            "required": ["word", "reading", "romaji", "pitch_accent", "jlpt_level", "part_of_speech", "transitivity"],
        },
        "2_meanings_and_nuance": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"definition": {"type": "STRING"}, "nuance": {"type": "STRING"}}}},
        "3_critical_grammar_rules": {"type": "OBJECT", "properties": {"associated_particles": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"pattern": {"type": "STRING"}, "explanation": {"type": "STRING"}}}}}},
        "4_conjugations": {"type": "OBJECT", "properties": {k: {"type": "STRING", "nullable": True} for k in CONJUGATION_KEYS}},
        "6_example_sentences": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"japanese": {"type": "STRING"}, "chinese": {"type": "STRING"}}}},
        "7_synonyms_and_antonyms": {"type": "OBJECT", "properties": {
            "synonyms": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"word": {"type": "STRING"}, "meaning": {"type": "STRING"}, "difference": {"type": "STRING"}}}},
            "antonyms": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"word": {"type": "STRING"}, "meaning": {"type": "STRING"}, "difference": {"type": "STRING"}}}},
        }},
        "8_collocations_and_phrases": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"phrase": {"type": "STRING"}, "meaning": {"type": "STRING"}}}},
        "9_common_mistakes_and_usage_notes": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"mistake_type": {"type": "STRING"}, "explanation": {"type": "STRING"}}}},
    },
    "required": ["1_basic_info", "2_meanings_and_nuance", "3_critical_grammar_rules", "4_conjugations",
                  "6_example_sentences", "7_synonyms_and_antonyms",
                  "8_collocations_and_phrases", "9_common_mistakes_and_usage_notes"],
}


# ============================================================
# 数据归一化
# ============================================================

KANJI_RE = re.compile(r"[一-龯々]")
# 匹配含汉字的 ruby 块: 纯汉字或汉字+假名混合 (如 お姉さん[おねえさん])
RUBY_BLOCK_RE = re.compile(r"(?:[^\[\]\s]*[一-龯々][^\[\]\s]*)\[[^\[\]]+\]")
RUBY_STRIP_RE = re.compile(r"([^\[\]\s]*[一-龯々][^\[\]\s]*)\[[^\[\]]+\]")
KANA_ONLY_RE = re.compile(r"[\u3040-\u309F\u30A0-\u30FFー・\s]+")
VERB_POS_MARKERS = ("动词", "自动词", "他动词", "五段动词", "一段动词", "サ变动词")


def clean(v):
    if v is None: return ""
    return str(v).strip() if isinstance(v, str) else str(v)


def has_japanese(text):
    for ch in clean(text):
        c = ord(ch)
        if 0x3040 <= c <= 0x309F or 0x30A0 <= c <= 0x30FF or 0x4E00 <= c <= 0x9FFF:
            return True
    return False


def has_kanji(text):
    return bool(KANJI_RE.search(clean(text)))


def strip_ruby(text):
    return RUBY_STRIP_RE.sub(r"\1", clean(text))


def has_unannotated_kanji(text):
    s = clean(text)
    if not s: return False
    covered = [False] * len(s)
    for m in RUBY_BLOCK_RE.finditer(s):
        for i in range(m.start(), m.end()):
            covered[i] = True
    return any(KANJI_RE.match(ch) and not covered[i] for i, ch in enumerate(s))


def normalize_ruby_text(v):
    t = clean(v)
    if not t: return ""
    return t


def hiragana_to_katakana(text):
    return "".join(chr(ord(ch) + 0x60) if 0x3041 <= ord(ch) <= 0x3096 else ch for ch in text)


def is_kana_only_word(word):
    w = clean(word)
    return bool(w) and bool(KANA_ONLY_RE.fullmatch(w))


def normalize_reading(word, reading):
    if is_kana_only_word(word):
        return ""
    r = clean(reading)
    if not r: return ""
    if re.fullmatch(r"[A-Z0-9][A-Z0-9&+\-]*", clean(word)):
        r = re.sub(r"\s+", "", r)
        r = hiragana_to_katakana(r)
    return r


def normalize_pitch(v):
    if v is None: return None
    t = clean(v)
    if not t: return None
    if t.lower() in NULL_STRINGS or t in {"无固定", "無固定", "不定"}:
        return None
    circled = [CIRCLED_DIGITS[ch] for ch in t if ch in CIRCLED_DIGITS]
    if circled: return "/".join(circled)
    compact = re.sub(r"\s+", "", t)
    if "平板" in compact and not re.search(r"\d", compact): return "0"
    nums = re.findall(r"\d+", compact)
    if nums:
        deduped = []
        for n in nums:
            if not deduped or deduped[-1] != n: deduped.append(n)
        return "/".join(deduped)
    return compact if re.fullmatch(r"\d+(\/\d+)*", compact) else None


def normalize_pos(v):
    pos = clean(v)
    if not pos or pos.lower() in NULL_STRINGS: return ""
    pos = pos.replace("，", "/").replace(",", "/").replace("、", "/").replace("／", "/")
    pos = re.sub(r"\s+", "", pos)
    for old, new in POS_SUBSTRING_MAP.items():
        pos = pos.replace(old, new)
    pos = POS_EXACT_MAP.get(pos, pos)
    parts = [p for p in pos.split("/") if p]
    if not parts: return ""
    seen, valid = set(), []
    for p in parts:
        mapped = POS_TOKEN_MAP.get(p, p)
        if mapped in PARTS_OF_SPEECH and mapped not in seen:
            valid.append(mapped); seen.add(mapped)
    return "/".join(valid)


def normalize_conj(v):
    if v is None: return None
    t = strip_ruby(v)
    if t.lower() in NO_CONJUGATION_MARKERS or t.endswith("无变形") or t.endswith("無変形"):
        return None
    return t or None


def has_verb_pos(pos):
    return any(marker in pos for marker in VERB_POS_MARKERS)


def normalize_jlpt(v):
    j = clean(v).upper()
    return j if j in JLPT_LEVELS else "N/A"


def normalize_transitivity(v):
    n = normalize_pos(v)
    return n if n in TRANSITIVITY_VALUES else None


def normalize_nullish(v):
    if isinstance(v, dict): return {k: normalize_nullish(val) for k, val in v.items()}
    if isinstance(v, list): return [normalize_nullish(x) for x in v]
    if isinstance(v, str) and v.strip().lower() in NULL_STRINGS: return None
    return v


def normalize_list(items, fields, ruby_fields=None):
    """通用列表归一化: 校验必填字段，可选 ruby 校验。"""
    out = []
    if not isinstance(items, list): return out
    for item in items:
        if not isinstance(item, dict): continue
        row = {f: clean(item.get(f)) for f in fields}
        if ruby_fields:
            for rf in ruby_fields:
                row[rf] = normalize_ruby_text(item.get(rf))
        if all(row.get(f) for f in fields): out.append(row)
    return out


def normalize_output_item(item, source_meta):
    """将 AI 输出归一化为标准格式。"""
    item = normalize_nullish(item or {})
    basic = dict(item.get("1_basic_info") or {})

    word = source_meta.get("word_text") or clean(basic.get("word"))
    reading = source_meta.get("moji_reading") or clean(basic.get("reading"))
    pitch_src = source_meta.get("moji_accent")

    # meanings
    meanings = []
    for m in (item.get("2_meanings_and_nuance") or []):
        if isinstance(m, dict) and clean(m.get("definition")):
            meanings.append({"definition": clean(m["definition"]), "nuance": clean(m.get("nuance"))})

    # grammar
    gr = item.get("3_critical_grammar_rules") or {}
    particles = normalize_list(
        gr.get("associated_particles") if isinstance(gr, dict) else [],
        ["pattern", "explanation"], ruby_fields=["pattern"]
    )

    # conjugations
    conj = item.get("4_conjugations") or {}
    part_of_speech = normalize_pos(basic.get("part_of_speech"))
    if not part_of_speech:
        part_of_speech = POS_FALLBACK_BY_MOJI_ID.get(source_meta.get("moji_word_id", ""), "")
    conj_out = {k: normalize_conj(conj.get(k) if isinstance(conj, dict) else None) for k in CONJUGATION_KEYS}
    if not has_verb_pos(part_of_speech):
        conj_out = {k: None for k in CONJUGATION_KEYS}

    # examples
    examples = normalize_list(item.get("6_example_sentences") or [], ["japanese", "chinese"], ruby_fields=["japanese"])

    # synonyms/antonyms
    sa = item.get("7_synonyms_and_antonyms") or {}
    if not isinstance(sa, dict): sa = {}
    syn = normalize_list(sa.get("synonyms") or [], ["word", "meaning"])
    for s in syn: s.setdefault("difference", "")
    ant = normalize_list(sa.get("antonyms") or [], ["word", "meaning"])
    for a in ant: a.setdefault("difference", "")

    # collocations
    collocations = normalize_list(item.get("8_collocations_and_phrases") or [], ["phrase", "meaning"], ruby_fields=["phrase"])

    # usage notes
    notes = normalize_list(item.get("9_common_mistakes_and_usage_notes") or [], ["mistake_type", "explanation"])

    return {
        "1_basic_info": {
            "word": word,
            "reading": normalize_reading(word, reading),
            "romaji": clean(basic.get("romaji")),
            "pitch_accent": normalize_pitch(pitch_src if pitch_src is not None else basic.get("pitch_accent")),
            "jlpt_level": normalize_jlpt(basic.get("jlpt_level")),
            "part_of_speech": part_of_speech,
            "transitivity": normalize_transitivity(basic.get("transitivity")),
        },
        "2_meanings_and_nuance": meanings,
        "3_critical_grammar_rules": {"associated_particles": particles},
        "4_conjugations": conj_out,
        "6_example_sentences": examples,
        "7_synonyms_and_antonyms": {"synonyms": syn, "antonyms": ant},
        "8_collocations_and_phrases": collocations,
        "9_common_mistakes_and_usage_notes": notes,
        "_source_meta": source_meta,
    }


def is_valid(item):
    basic = item.get("1_basic_info", {})
    if not basic.get("word"): return False
    if not basic.get("reading") and not is_kana_only_word(basic.get("word")): return False
    if basic.get("jlpt_level") not in JLPT_LEVELS: return False
    pos = basic.get("part_of_speech", "")
    if not pos: return False
    if any(t not in PARTS_OF_SPEECH for t in pos.split("/")): return False
    t = basic.get("transitivity")
    if t is not None and t not in TRANSITIVITY_VALUES: return False
    p = basic.get("pitch_accent")
    if p is not None and not re.fullmatch(r"\d+(\/\d+)*", str(p)): return False
    if not item.get("2_meanings_and_nuance"): return False
    if not item.get("6_example_sentences"): return False
    return True


# ============================================================
# 辅助函数
# ============================================================

def flatten_moji_tree(items):
    words = []
    for item in items:
        if item.get("type") == "folder":
            words.extend(flatten_moji_tree(item.get("items", [])))
        elif item.get("type") == "word":
            words.append(item)
    return words


def build_lesson_map(tree, book_id):
    lessons = []
    counter = [0]

    def walk(node, path):
        if isinstance(node, list):
            for child in node: walk(child, path)
            return
        if not isinstance(node, dict): return
        if "title" in node and "items" in node:
            new_path = path + [node["title"]]
            children = node.get("items", [])
            has_words = any(isinstance(c, dict) and "wordId" in c for c in children)
            if has_words:
                counter[0] += 1
                num = counter[0]
                word_list = [c for c in children if isinstance(c, dict) and "wordId" in c]
                lessons.append({
                    "id": make_uuid("lesson", f"{book_id}:{num}"),
                    "number": num,
                    "title": " / ".join(new_path),
                    "words": word_list,
                })
                for c in children:
                    if isinstance(c, dict) and "wordId" not in c: walk(c, new_path)
            else:
                for c in children: walk(c, new_path)

    walk(tree, [])
    return lessons


def check_cloud_existing(word_ids, supabase_key):
    existing = set()
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    for i in range(0, len(word_ids), 100):
        chunk = word_ids[i:i+100]
        try:
            resp = requests.get(
                f"{SUPABASE_URL}/rest/v1/words",
                params={"id": f"in.({','.join(chunk)})", "select": "id"},
                headers=headers, timeout=20,
            )
            if resp.ok:
                for row in resp.json(): existing.add(row["id"])
        except Exception as e:
            print(f"  ⚠️ 云端查询异常: {e}")
    return existing


def make_placeholder(entry, status):
    return {
        "_word_id": entry["word_id"],
        "_lesson": entry["lesson"],
        "_sort_order": entry["sort_order"],
        "_book_sort_order": entry["book_sort_order"],
        "1_basic_info": {
            "word": entry["word_text"], "reading": entry["reading"],
            "romaji": "", "pitch_accent": None, "jlpt_level": "",
            "part_of_speech": "", "transitivity": None,
        },
        "2_meanings_and_nuance": [],
        "3_critical_grammar_rules": {"associated_particles": []},
        "4_conjugations": {k: None for k in CONJUGATION_KEYS},
        "6_example_sentences": [],
        "7_synonyms_and_antonyms": {"synonyms": [], "antonyms": []},
        "8_collocations_and_phrases": [],
        "9_common_mistakes_and_usage_notes": [],
        "_source_meta": {**entry["source_meta"], "generation_status": status},
    }


def save_output(output_file, data, args, book_id, total):
    data["_meta"] = {
        "book_name": args.book_name, "book_title": args.book_title,
        "book_id": book_id, "total_words": total,
        "generated_count": len(data.get("words", [])), "version": "4.0",
    }
    output_file.parent.mkdir(parents=True, exist_ok=True)
    tmp = output_file.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    tmp.rename(output_file)


# ============================================================
# 主逻辑
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="AI 单词数据生成器 v4")
    parser.add_argument("--book-name", required=True)
    parser.add_argument("--book-title", required=True)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--retry-failed", action="store_true")
    parser.add_argument("--skip-cloud-check", action="store_true")
    args = parser.parse_args()

    root = config.PROJECT_ROOT
    api_key = config.gemini_api_key()

    words_json = root / SOURCES_DIR / args.book_name / "words.json"
    output_file = root / GENERATED_DIR / f"{args.book_name}.json"
    checkpoint_dir = root / CHECKPOINTS_DIR
    trace_dir = root / LOGS_DIR / "vocab_generator_response_traces" / args.book_name
    rate_checkpoint = checkpoint_dir / "gemini_rpd.json"

    output_file.parent.mkdir(parents=True, exist_ok=True)
    checkpoint_dir.mkdir(parents=True, exist_ok=True)

    if not words_json.exists():
        print(f"❌ 找不到数据源: {words_json}")
        sys.exit(1)

    with open(words_json, "r", encoding="utf-8") as f:
        moji_tree = json.load(f)

    book_id = make_uuid("book", args.book_title)
    lesson_map = build_lesson_map(moji_tree, book_id)

    # 构建有序词条列表
    ordered = []
    gidx = 0
    for lesson in lesson_map:
        for si, w in enumerate(lesson["words"]):
            word_text = w.get("word", "")
            if not has_japanese(word_text): continue
            reading = w.get("reading", "")
            word_id = make_uuid("word", f"{word_text.strip()}:{reading.strip()}")
            moji_id = w.get("wordId") or w.get("targetId") or ""
            ordered.append({
                "word_id": word_id,
                "moji_word_id": str(moji_id),
                "word_text": word_text,
                "reading": reading,
                "source_meta": {
                    "moji_word_id": str(moji_id),
                    "moji_target_id": str(w.get("targetId", "")),
                    "word_text": word_text,
                    "moji_reading": reading,
                    "moji_accent": normalize_pitch(w.get("accent", "")),
                    "moji_meaning": w.get("meaning", ""),
                    "source": "mojidict",
                },
                "lesson": {"id": lesson["id"], "number": lesson["number"], "title": lesson["title"]},
                "sort_order": si,
                "book_sort_order": gidx,
            })
            gidx += 1

    print(f"\n📖 辞书: {args.book_title}")
    print(f"   总词条: {len(ordered)} | 课数: {len(lesson_map)}")

    # 加载已有输出
    output = {"_meta": {}, "words": []}
    done_ids, fail_ids = set(), set()

    if args.resume and output_file.exists():
        with open(output_file, "r", encoding="utf-8") as f:
            output = json.load(f)
        for w in output.get("words", []):
            mid = w.get("_source_meta", {}).get("moji_word_id", "")
            st = w.get("_source_meta", {}).get("generation_status", "")
            if mid:
                if st == "FAILED_SKIP": fail_ids.add(mid)
                elif st in ("SUCCESS", "CLOUD_REFERENCE"): done_ids.add(mid)
        print(f"   已完成: {len(done_ids)} | 失败: {len(fail_ids)}")

    # 筛选待处理
    to_process = []
    for e in ordered:
        mid = e["moji_word_id"]
        if mid in done_ids: continue
        if mid in fail_ids:
            if args.retry_failed:
                output["words"] = [w for w in output.get("words", [])
                                   if w.get("_source_meta", {}).get("moji_word_id") != mid]
            else:
                continue
        to_process.append(e)

    # 云端查重
    supa_key = config.get("SUPABASE_SERVICE_KEY")
    if not args.skip_cloud_check and supa_key and to_process:
        print(f"\n🔍 云端查重中...")
        cloud = check_cloud_existing([e["word_id"] for e in to_process], supa_key)
        if cloud:
            new_proc = []
            for e in to_process:
                if e["word_id"] in cloud:
                    output.setdefault("words", []).append(make_placeholder(e, "CLOUD_REFERENCE"))
                else:
                    new_proc.append(e)
            to_process = new_proc
            print(f"   云端已存在: {len(cloud)} 条")

    print(f"\n🤖 待 AI 生成: {len(to_process)} 条")

    if not to_process:
        save_output(output_file, output, args, book_id, len(ordered))
        print(f"\n✅ 全部完成！输出: {output_file}")
        return

    # Gemini 客户端
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    gen_config = types.GenerateContentConfig(
        system_instruction=SYSTEM_PROMPT,
        response_mime_type="application/json",
        response_schema={"type": "ARRAY", "items": ITEM_SCHEMA},
        temperature=0.0,
        max_output_tokens=GEMINI_MAX_OUTPUT_TOKENS,
    )

    limiter = RateLimiter(rpm=GEMINI_RPM, tpm=GEMINI_TPM, rpd=GEMINI_RPD, checkpoint_file=rate_checkpoint)
    status = limiter.status()
    print(f"   RPD 今日已用: {status['rpd_used']}/{status['rpd_limit']}\n")

    consecutive_503 = 0
    total_batches = (len(to_process) + GEMINI_BATCH_SIZE - 1) // GEMINI_BATCH_SIZE
    MAX_RETRIES = 10

    def process_batch(batch, label):
        nonlocal consecutive_503

        if not limiter.check_rpd():
            print(f"\n⏸️  RPD 配额耗尽，请明天 --resume 继续")
            save_output(output_file, output, args, book_id, len(ordered))
            sys.exit(0)

        prompt = build_batch_prompt(batch)
        names = [e["word_text"] for e in batch]
        print(f"[{label}] {', '.join(names)}")

        est_tokens = len(prompt) * 2 + GEMINI_MAX_OUTPUT_TOKENS
        limiter.wait_if_needed(est_tokens)

        for attempt in range(MAX_RETRIES):
            resp_text = ""
            try:
                response = client.models.generate_content(
                    model=GEMINI_MODEL, contents=prompt, config=gen_config,
                )
                limiter.record_request(est_tokens)
                consecutive_503 = 0

                resp_text = getattr(response, "text", "") or ""

                # 检测截断: finish_reason 不是 STOP
                finish_reason = None
                if hasattr(response, "candidates") and response.candidates:
                    finish_reason = getattr(response.candidates[0], "finish_reason", None)
                if finish_reason and str(finish_reason) not in ("FinishReason.STOP", "STOP", "1"):
                    raise ValueError(f"输出被截断 (finish_reason={finish_reason}), 可能 token 不足")

                # 优先用 SDK parsed，否则 json.loads
                parsed = getattr(response, "parsed", None)
                if isinstance(parsed, list):
                    data = parsed
                elif isinstance(parsed, dict) and isinstance(parsed.get("items"), list):
                    data = parsed["items"]
                else:
                    data = json.loads(resp_text)

                if not isinstance(data, list):
                    raise ValueError("返回不是数组")
                if len(data) != len(batch):
                    raise ValueError(f"数量不匹配: 期望 {len(batch)} 得到 {len(data)}")

                items = []
                for idx, ai_item in enumerate(data):
                    if not isinstance(ai_item, dict):
                        raise ValueError(f"第 {idx+1} 条不是对象")
                    norm = normalize_output_item(ai_item, batch[idx]["source_meta"])
                    if not is_valid(norm):
                        raise ValueError(f"第 {idx+1} 条校验失败: {batch[idx]['word_text']}")
                    norm["_source_meta"]["generation_status"] = "SUCCESS"
                    items.append({
                        "_word_id": batch[idx]["word_id"],
                        "_lesson": batch[idx]["lesson"],
                        "_sort_order": batch[idx]["sort_order"],
                        "_book_sort_order": batch[idx]["book_sort_order"],
                        **norm,
                    })

                output.setdefault("words", []).extend(items)
                save_output(output_file, output, args, book_id, len(ordered))
                print(f"   ✅ 成功")
                return True

            except Exception as e:
                err = str(e)
                is_429 = "429" in err or "RESOURCE_EXHAUSTED" in err
                is_503 = "503" in err or "UNAVAILABLE" in err

                # 记录追踪（仅格式/校验错误）
                if not is_429 and not is_503:
                    trace_dir.mkdir(parents=True, exist_ok=True)
                    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
                    tf = trace_dir / f"{ts}-batch-{label.replace('/', '_')}-attempt-{attempt+1}.json"
                    with open(tf, "w", encoding="utf-8") as fh:
                        json.dump({"error": err, "response_text": resp_text, "prompt": prompt},
                                  fh, ensure_ascii=False, indent=2)

                if is_429:
                    limiter.record_request(0)
                    print(f"\n🛑 429 限流，保存退出。--resume 继续")
                    save_output(output_file, output, args, book_id, len(ordered))
                    sys.exit(0)

                if is_503:
                    consecutive_503 += 1
                    wait_503 = min(15 * (2 ** attempt), 300)
                    print(f"   ❌ ({attempt+1}/{MAX_RETRIES}) [503]: {err[:120]}")
                    if attempt < MAX_RETRIES - 1:
                        print(f"      等待 {wait_503}s...")
                        time.sleep(wait_503)
                    continue

                wait = min(10 + attempt * 15, 90)
                tag = ""
                print(f"   ❌ ({attempt+1}/{MAX_RETRIES}){tag}: {err[:120]}")
                if attempt < MAX_RETRIES - 1:
                    print(f"      等待 {wait}s...")
                    time.sleep(wait)

        print(f"   ⚠️ {MAX_RETRIES} 次全败，标记 FAILED_SKIP")
        for e in batch:
            output.setdefault("words", []).append(make_placeholder(e, "FAILED_SKIP"))
        save_output(output_file, output, args, book_id, len(ordered))
        return False

    for i in range(0, len(to_process), GEMINI_BATCH_SIZE):
        batch = to_process[i:i + GEMINI_BATCH_SIZE]
        batch_num = i // GEMINI_BATCH_SIZE + 1
        process_batch(batch, f"{batch_num}/{total_batches}")
        time.sleep(GEMINI_WAIT_BETWEEN)

    # 统计
    words = output.get("words", [])
    sc = sum(1 for w in words if w.get("_source_meta", {}).get("generation_status") == "SUCCESS")
    fc = sum(1 for w in words if w.get("_source_meta", {}).get("generation_status") == "FAILED_SKIP")
    cc = sum(1 for w in words if w.get("_source_meta", {}).get("generation_status") == "CLOUD_REFERENCE")
    st = limiter.status()

    print(f"\n{'='*50}")
    print(f"  ✅ 完成! 总: {len(words)} | AI: {sc} | 云端: {cc} | 失败: {fc}")
    print(f"  RPD: {st['rpd_used']}/{st['rpd_limit']}")
    print(f"  输出: {output_file}")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()
