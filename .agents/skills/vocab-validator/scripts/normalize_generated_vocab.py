#!/usr/bin/env python3
"""
批量归一化 generated 词条 JSON。

目标：
1. 清理 4_conjugations 中的占位值（N/A / none / 无变形 等）为 null
2. 清理常见基础字段中的占位值为 null
3. 保留 ruby 格式，交由前端 ruby 组件渲染
"""

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import (
    GENERATED_DIR,
    SOURCES_DIR,
    PARTS_OF_SPEECH,
    CONJUGATION_KEYS,
    NO_CONJUGATION_MARKERS,
    NULL_STRINGS,
    POS_FALLBACK_BY_MOJI_ID,
    POS_TOKEN_MAP,
    POS_SUBSTRING_MAP,
    POS_EXACT_MAP,
    TRANSITIVITY_VALUES,
    make_uuid,
)


PLACEHOLDER_VALUES = {
    "n/a",
    "na",
    "none",
    "null",
    "nil",
    "无",
    "無",
    "不适用",
    "不適用",
}

BASIC_OPTIONAL_KEYS = ("jlpt_level", "transitivity", "pitch_accent", "romaji")
KANA_ONLY_RE = re.compile(r"[\u3040-\u309F\u30A0-\u30FFー・\s]+")
VERB_POS_MARKERS = ("动词", "自动词", "他动词", "五段动词", "一段动词", "サ变动词")
CANONICAL_SOURCE_META_KEYS = (
    "moji_word_id",
    "moji_target_id",
    "word_text",
    "moji_reading",
    "moji_accent",
    "moji_meaning",
    "source",
    "generation_status",
)
BOOK_TITLE_MAP = {
    "新标日初级上册": "新标准日本语初级上册",
    "新标日初级下册": "新标准日本语初级下册",
    "新标日中级上册": "新标准日本语中级上册",
    "新标日中级下册": "新标准日本语中级下册",
}


def flatten_moji_tree(items):
    words = []
    for item in items:
        if not isinstance(item, dict):
            continue
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
            for child in node:
                walk(child, path)
            return
        if not isinstance(node, dict):
            return

        title = node.get("title")
        children = node.get("items")
        if title is None or not isinstance(children, list):
            return

        new_path = path + [title]
        has_words = any(
            isinstance(child, dict) and (child.get("wordId") or child.get("targetId"))
            for child in children
        )
        if has_words:
            counter[0] += 1
            number = counter[0]
            word_list = [
                child
                for child in children
                if isinstance(child, dict) and (child.get("wordId") or child.get("targetId"))
            ]
            lessons.append({
                "id": make_uuid("lesson", f"{book_id}:{number}"),
                "number": number,
                "title": " / ".join(new_path),
                "words": word_list,
            })
            for child in children:
                if isinstance(child, dict) and not (child.get("wordId") or child.get("targetId")):
                    walk(child, new_path)
            return

        for child in children:
            walk(child, new_path)

    walk(tree, [])
    return lessons


def normalize_pitch(value):
    normalized = normalize_string(value)
    if normalized is None:
        return None
    translation = str.maketrans("①②③④⑤⑥⑦⑧⑨⓪", "1234567890")
    normalized = normalized.translate(translation)
    normalized = normalized.replace("/", "/")
    return normalized


def build_ordered_source_entries(book_name):
    source_file = config.PROJECT_ROOT / SOURCES_DIR / book_name / "words.json"
    if not source_file.exists():
        raise FileNotFoundError(f"missing source words.json for {book_name}: {source_file}")

    with source_file.open("r", encoding="utf-8") as handle:
        moji_tree = json.load(handle)

    book_title = BOOK_TITLE_MAP.get(book_name, book_name.replace("新标日", "新标准日本语", 1))
    book_id = make_uuid("book", book_title)
    lesson_map = build_lesson_map(moji_tree, book_id)

    ordered = []
    global_index = 0
    for lesson in lesson_map:
        for sort_index, word in enumerate(lesson["words"]):
            word_text = (word.get("word") or "").strip()
            reading = (word.get("reading") or "").strip()
            moji_id = str(word.get("wordId") or word.get("targetId") or "")
            if not moji_id:
                continue
            ordered.append({
                "moji_word_id": moji_id,
                "word_text": word_text,
                "reading": reading,
                "word_id": make_uuid("word", f"{word_text}:{reading}"),
                "lesson": {
                    "id": lesson["id"],
                    "number": lesson["number"],
                    "title": lesson["title"],
                },
                "sort_order": sort_index,
                "book_sort_order": global_index,
                "source_meta": {
                    "moji_word_id": moji_id,
                    "moji_target_id": str(word.get("targetId") or ""),
                    "word_text": word_text,
                    "moji_reading": reading,
                    "moji_accent": normalize_pitch(word.get("accent")),
                    "moji_meaning": word.get("meaning") or "",
                    "source": "mojidict",
                    "generation_status": "SUCCESS",
                },
            })
            global_index += 1

    by_moji_id = {entry["moji_word_id"]: entry for entry in ordered}
    return {
        "book_name": book_name,
        "book_title": book_title,
        "book_id": book_id,
        "total_words": len(ordered),
        "ordered": ordered,
        "by_moji_id": by_moji_id,
    }


def migrate_legacy_root(file_path: Path, data):
    if not isinstance(data, list):
        return data, 0

    book_name = file_path.stem
    source = build_ordered_source_entries(book_name)
    migrated_words = []
    migrated_count = 0

    for index, entry in enumerate(data):
        if not isinstance(entry, dict):
            migrated_words.append(entry)
            continue

        meta = entry.get("_source_meta")
        if not isinstance(meta, dict):
            meta = {}
            entry["_source_meta"] = meta

        moji_id = str(meta.get("moji_word_id") or meta.get("moji_target_id") or "")
        source_entry = source["by_moji_id"].get(moji_id)
        if source_entry is None and index < len(source["ordered"]):
            source_entry = source["ordered"][index]

        if source_entry is not None:
            entry.setdefault("_word_id", source_entry["word_id"])
            entry.setdefault("_lesson", source_entry["lesson"])
            entry.setdefault("_sort_order", source_entry["sort_order"])
            entry.setdefault("_book_sort_order", source_entry["book_sort_order"])
            for key, value in source_entry["source_meta"].items():
                if key not in meta or meta.get(key) in (None, ""):
                    meta[key] = value
        else:
            basic = entry.get("1_basic_info") if isinstance(entry.get("1_basic_info"), dict) else {}
            word_text = (basic.get("word") or meta.get("word_text") or "").strip()
            reading = (basic.get("reading") or meta.get("moji_reading") or "").strip()
            entry.setdefault("_word_id", make_uuid("word", f"{word_text}:{reading}"))
            entry.setdefault("_lesson", {"id": "", "number": 0, "title": ""})
            entry.setdefault("_sort_order", 0)
            entry.setdefault("_book_sort_order", index)
            meta.setdefault("word_text", word_text)
            meta.setdefault("moji_reading", reading)
            meta.setdefault("source", "mojidict")
            meta.setdefault("generation_status", "SUCCESS")

        migrated_count += 1
        migrated_words.append(entry)

    return {
        "_meta": {
            "book_name": source["book_name"],
            "book_title": source["book_title"],
            "book_id": source["book_id"],
            "total_words": source["total_words"],
            "generated_count": len(migrated_words),
            "version": "4.0",
        },
        "words": migrated_words,
    }, migrated_count


def ensure_standard_root(file_path: Path, data):
    migrated_count = 0
    if isinstance(data, list):
        data, migrated_count = migrate_legacy_root(file_path, data)

    if not isinstance(data, dict):
        return data, migrated_count

    words = data.get("words")
    if not isinstance(words, list):
        return data, migrated_count

    book_name = file_path.stem
    source = build_ordered_source_entries(book_name)
    meta = data.get("_meta")
    if not isinstance(meta, dict):
        meta = {}
        data["_meta"] = meta

    meta["book_name"] = source["book_name"]
    meta["book_title"] = source["book_title"]
    meta["book_id"] = source["book_id"]
    meta["total_words"] = source["total_words"]
    meta["generated_count"] = len(words)
    meta["version"] = "4.0"
    return data, migrated_count


def normalize_string(value):
    if value is None:
        return None
    if not isinstance(value, str):
        value = str(value)
    normalized = value.strip()
    if not normalized:
        return None
    lowered = normalized.lower()
    if lowered in PLACEHOLDER_VALUES or lowered in NO_CONJUGATION_MARKERS:
        return None
    return normalized


def clean(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def is_kana_only_word(word):
    normalized = clean(word)
    return bool(normalized) and bool(KANA_ONLY_RE.fullmatch(normalized))


def normalize_pos(value):
    pos = clean(value)
    if not pos or pos.lower() in NULL_STRINGS:
        return ""
    pos = pos.replace("，", "/").replace(",", "/").replace("、", "/").replace("／", "/")
    pos = re.sub(r"\s+", "", pos)
    for old, new in POS_SUBSTRING_MAP.items():
        pos = pos.replace(old, new)
    pos = POS_EXACT_MAP.get(pos, pos)
    parts = [part for part in pos.split("/") if part]
    if not parts:
        return ""
    seen = set()
    normalized_parts = []
    for part in parts:
        mapped = POS_TOKEN_MAP.get(part, part)
        if mapped in PARTS_OF_SPEECH and mapped not in seen:
            normalized_parts.append(mapped)
            seen.add(mapped)
    return "/".join(normalized_parts)


def normalize_transitivity(value):
    normalized = normalize_pos(value)
    return normalized if normalized in TRANSITIVITY_VALUES else None


def has_verb_pos(value):
    pos = clean(value)
    return any(marker in pos for marker in VERB_POS_MARKERS)


def canonicalize_source_meta(meta):
    canonical = {}
    meta = meta if isinstance(meta, dict) else {}
    for key in CANONICAL_SOURCE_META_KEYS:
        canonical[key] = meta.get(key)
    return canonical


def canonicalize_basic_info(basic):
    basic = basic if isinstance(basic, dict) else {}
    return {
        "word": basic.get("word", ""),
        "reading": basic.get("reading", ""),
        "romaji": basic.get("romaji"),
        "pitch_accent": basic.get("pitch_accent"),
        "jlpt_level": basic.get("jlpt_level"),
        "part_of_speech": basic.get("part_of_speech", ""),
        "transitivity": basic.get("transitivity"),
    }


def canonicalize_lesson(lesson):
    lesson = lesson if isinstance(lesson, dict) else {}
    return {
        "id": lesson.get("id", ""),
        "number": lesson.get("number", 0),
        "title": lesson.get("title", ""),
    }


def canonicalize_conjugations(conjugations):
    conjugations = conjugations if isinstance(conjugations, dict) else {}
    return {key: conjugations.get(key) for key in CONJUGATION_KEYS}


def canonicalize_entry(entry):
    return {
        "_word_id": entry.get("_word_id", ""),
        "_lesson": canonicalize_lesson(entry.get("_lesson")),
        "_sort_order": entry.get("_sort_order", 0),
        "_book_sort_order": entry.get("_book_sort_order", 0),
        "1_basic_info": canonicalize_basic_info(entry.get("1_basic_info")),
        "2_meanings_and_nuance": entry.get("2_meanings_and_nuance", []),
        "3_critical_grammar_rules": entry.get("3_critical_grammar_rules", {}),
        "4_conjugations": canonicalize_conjugations(entry.get("4_conjugations")),
        "6_example_sentences": entry.get("6_example_sentences", []),
        "7_synonyms_and_antonyms": entry.get("7_synonyms_and_antonyms", {"synonyms": [], "antonyms": []}),
        "8_collocations_and_phrases": entry.get("8_collocations_and_phrases", []),
        "9_common_mistakes_and_usage_notes": entry.get("9_common_mistakes_and_usage_notes", []),
        "_source_meta": canonicalize_source_meta(entry.get("_source_meta")),
    }


def needs_canonical_reorder(entry):
    if not isinstance(entry, dict):
        return False
    if list(entry.keys()) != list(canonicalize_entry(entry).keys()):
        return True
    meta = entry.get("_source_meta")
    if isinstance(meta, dict) and list(meta.keys()) != list(CANONICAL_SOURCE_META_KEYS):
        return True
    return False


def normalize_entry(entry):
    changed = False

    basic = entry.get("1_basic_info")
    meta = entry.get("_source_meta") if isinstance(entry.get("_source_meta"), dict) else {}
    if isinstance(basic, dict):
        normalized_pos = normalize_pos(basic.get("part_of_speech"))
        if not normalized_pos:
            normalized_pos = POS_FALLBACK_BY_MOJI_ID.get(meta.get("moji_word_id", ""), "")
        if basic.get("part_of_speech") != normalized_pos:
            basic["part_of_speech"] = normalized_pos
            changed = True

        normalized_transitivity = normalize_transitivity(basic.get("transitivity"))
        if basic.get("transitivity") != normalized_transitivity:
            basic["transitivity"] = normalized_transitivity
            changed = True

        for key in BASIC_OPTIONAL_KEYS:
            if key == "transitivity":
                continue
            normalized = normalize_string(basic.get(key))
            if basic.get(key) != normalized:
                basic[key] = normalized
                changed = True

        if is_kana_only_word(basic.get("word")) and basic.get("reading") != "":
            basic["reading"] = ""
            changed = True

    conjugations = entry.get("4_conjugations")
    if isinstance(conjugations, dict):
        if not has_verb_pos((basic or {}).get("part_of_speech")):
            for key in CONJUGATION_KEYS:
                if conjugations.get(key) is not None:
                    conjugations[key] = None
                    changed = True
        else:
            for key in CONJUGATION_KEYS:
                normalized = normalize_string(conjugations.get(key))
                if conjugations.get(key) != normalized:
                    conjugations[key] = normalized
                    changed = True

        for key in CONJUGATION_KEYS:
            if key not in conjugations:
                conjugations[key] = None
                changed = True

    if "5_kanji_components" in entry:
        entry.pop("5_kanji_components", None)
        changed = True

    return changed


def normalize_file(file_path: Path):
    with file_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    data, migrated_count = ensure_standard_root(file_path, data)
    if not isinstance(data, dict):
        return 0

    words = data.get("words")

    if not isinstance(words, list):
        return 0

    changed_count = 0
    reordered = False
    canonical_words = []
    for entry in words:
        if isinstance(entry, dict) and normalize_entry(entry):
            changed_count += 1
        if isinstance(entry, dict):
            if needs_canonical_reorder(entry):
                reordered = True
            canonical_words.append(canonicalize_entry(entry))
        else:
            canonical_words.append(entry)

    if reordered:
        data["words"] = canonical_words

    if changed_count or migrated_count or reordered:
        with file_path.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")

    if migrated_count:
        return migrated_count
    return changed_count


def main():
    parser = argparse.ArgumentParser(description="归一化 generated 单词数据")
    parser.add_argument("--book-name", help="只处理单本辞书")
    args = parser.parse_args()

    generated_dir = config.PROJECT_ROOT / GENERATED_DIR
    if args.book_name:
        files = [generated_dir / f"{args.book_name}.json"]
    else:
        files = sorted(generated_dir.glob("*.json"))

    total_files = 0
    total_entries = 0
    for file_path in files:
        if not file_path.exists():
            continue
        total_files += 1
        changed_entries = normalize_file(file_path)
        total_entries += changed_entries
        print(f"{file_path.name}: normalized {changed_entries} entries")

    print(f"processed files: {total_files}, normalized entries: {total_entries}")


if __name__ == "__main__":
    main()