#!/usr/bin/env python3
"""Normalize MOJi words.json into unit -> lesson grouped structure.

This script merges split lesson parts (课文/会话/关联词语...) into one lesson node,
then sorts by unit and lesson order.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import OrderedDict
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parents[4]
SOURCES_DIR = PROJECT_ROOT / "data" / "vocab" / "sources"

DIGITS = "零一二三四五六七八九"
REVERSE_DIGITS = {ch: i for i, ch in enumerate(DIGITS)}

UNIT_ARABIC_RE = re.compile(r"^第\s*(\d+)\s*单元$")
UNIT_CN_RE = re.compile(r"^第([一二三四五六七八九十]+)单元$")
LESSON_ARABIC_RE = re.compile(r"^第\s*(\d+)\s*课(?:\s*[-－—]\s*.*)?$")
LESSON_CN_RE = re.compile(r"^第([一二三四五六七八九十]+)课(?:\s*[-－—]\s*.*)?$")


def to_cn(n: int) -> str:
    if n < 10:
        return DIGITS[n]
    if n < 20:
        return "十" if n == 10 else "十" + DIGITS[n % 10]
    if n < 100:
        t, o = divmod(n, 10)
        return DIGITS[t] + "十" + (DIGITS[o] if o else "")
    return str(n)


def cn_to_int(text: str) -> int | None:
    if not text:
        return None
    if text == "十":
        return 10
    if text.startswith("十"):
        one = REVERSE_DIGITS.get(text[1:])
        return 10 + one if one is not None else None
    if "十" in text:
        ten, one = text.split("十", 1)
        ten_val = REVERSE_DIGITS.get(ten)
        if ten_val is None:
            return None
        if not one:
            return ten_val * 10
        one_val = REVERSE_DIGITS.get(one)
        return ten_val * 10 + one_val if one_val is not None else None
    return REVERSE_DIGITS.get(text)


def extract_unit_num(title: str) -> int | None:
    m = UNIT_ARABIC_RE.match(title)
    if m:
        return int(m.group(1))
    m = UNIT_CN_RE.match(title)
    if m:
        return cn_to_int(m.group(1))
    return None


def extract_lesson_num(title: str) -> int | None:
    m = LESSON_ARABIC_RE.match(title)
    if m:
        return int(m.group(1))
    m = LESSON_CN_RE.match(title)
    if m:
        return cn_to_int(m.group(1))
    return None


def collect_words(nodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    words: list[dict[str, Any]] = []

    def _walk(items: list[dict[str, Any]]) -> None:
        for item in items:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "word":
                words.append(item)
            elif item.get("type") == "folder":
                _walk(item.get("items", []))

    _walk(nodes)
    return words


def normalize_words_data(data: list[dict[str, Any]]) -> list[dict[str, Any]]:
    new_units: list[dict[str, Any]] = []
    pending_no_unit: list[dict[str, Any]] = []

    for unit in data:
        if not isinstance(unit, dict) or unit.get("type") != "folder":
            pending_no_unit.append(unit)
            continue

        unit_title = (unit.get("title") or "").strip()
        unit_num = extract_unit_num(unit_title)

        lesson_map: "OrderedDict[int, dict[str, Any]]" = OrderedDict()
        last_lesson_num: int | None = None

        for child in unit.get("items", []):
            if not isinstance(child, dict) or child.get("type") != "folder":
                continue

            child_title = (child.get("title") or "").strip()
            lesson_num = extract_lesson_num(child_title)

            if lesson_num is not None:
                last_lesson_num = lesson_num
            elif last_lesson_num is not None:
                # Titles like "关联词语(...)" belong to the most recent lesson.
                lesson_num = last_lesson_num
            else:
                continue

            if lesson_num not in lesson_map:
                lesson_map[lesson_num] = {
                    "id": child.get("id") or f"lesson_{lesson_num}",
                    "items": [],
                }

            lesson_map[lesson_num]["items"].extend(collect_words(child.get("items", [])))

        lesson_items: list[dict[str, Any]] = []
        for lesson_num in sorted(lesson_map.keys()):
            lesson_items.append(
                {
                    "type": "folder",
                    "title": f"第{to_cn(lesson_num)}课",
                    "id": lesson_map[lesson_num]["id"],
                    "items": lesson_map[lesson_num]["items"],
                }
            )

        new_units.append(
            {
                "type": "folder",
                "title": f"第{to_cn(unit_num)}单元" if unit_num is not None else unit_title,
                "id": unit.get("id"),
                "items": lesson_items,
            }
        )

    def unit_sort_key(unit: dict[str, Any]) -> int:
        return extract_unit_num((unit.get("title") or "").strip()) or 999

    new_units.sort(key=unit_sort_key)
    return new_units + pending_no_unit


def count_words(data: list[dict[str, Any]]) -> int:
    count = 0
    stack = list(data)
    while stack:
        node = stack.pop()
        if not isinstance(node, dict):
            continue
        if node.get("type") == "word":
            count += 1
        elif node.get("type") == "folder":
            stack.extend(node.get("items", []))
    return count


def normalize_file(book_name: str, in_place: bool = True) -> tuple[Path, int, int]:
    path = SOURCES_DIR / book_name / "words.json"
    if not path.exists():
        raise FileNotFoundError(f"words.json not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    before = count_words(data)
    normalized = normalize_words_data(data)
    after = count_words(normalized)

    if before != after:
        raise ValueError(f"Word count mismatch for {book_name}: {before} -> {after}")

    out_path = path if in_place else path.with_name("words.normalized.json")
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(normalized, f, ensure_ascii=False, indent=2)

    return out_path, before, after


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalize MOJi words.json to unit -> lesson structure")
    parser.add_argument(
        "--book-name",
        action="append",
        required=True,
        help="Book name under data/vocab/sources/. Repeat this flag for multiple books.",
    )
    parser.add_argument(
        "--no-in-place",
        action="store_true",
        help="Write to words.normalized.json instead of overwriting words.json.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    in_place = not args.no_in_place

    for book in args.book_name:
        out_path, before, after = normalize_file(book_name=book, in_place=in_place)
        print(f"✅ NORMALIZED: {book}")
        print(f"   file: {out_path}")
        print(f"   words: {before} -> {after}")


if __name__ == "__main__":
    main()
