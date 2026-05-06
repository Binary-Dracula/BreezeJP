#!/usr/bin/env python3
"""
修复被 CLOUD_REFERENCE UPSERT 覆盖的云端数据
=============================================
扫描全部 6 册生成 JSON，找到 SUCCESS 词条作为"正确来源"，
然后对云端 words + word_details + word_examples 中数据缺失的词进行 PATCH 补全。

用法:
    python .agents/skills/vocab-uploader/scripts/repair_cloud_ref.py [--dry-run]
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import (
    SUPABASE_URL, GENERATED_DIR, UPLOAD_BATCH_SIZE, UPLOAD_READ_BATCH_SIZE,
    REQUEST_TIMEOUT, make_uuid, CONJUGATION_KEYS,
)
from _vocab_common.retry import retry_call

import requests

KANA_ONLY_RE = __import__("re").compile(r"[\u3040-\u309F\u30A0-\u30FFー・\s]+")


# ============================================================
# Supabase 操作
# ============================================================

def _sb_headers():
    key = config.supabase_service_key()
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def sb_read(table, params):
    def _do():
        resp = requests.get(
            f"{SUPABASE_URL}/rest/v1/{table}", params=params,
            headers=_sb_headers(), timeout=REQUEST_TIMEOUT,
        )
        if resp.ok:
            return resp.json()
        raise RuntimeError(f"读取失败 {table}: {resp.status_code} {resp.text[:200]}")
    return retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


def sb_upsert(table, rows, on_conflict="id"):
    if not rows:
        return
    headers = {**_sb_headers(), "Prefer": "return=minimal,resolution=merge-duplicates"}

    def _do():
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/{table}", params={"on_conflict": on_conflict},
            json=rows, headers=headers, timeout=REQUEST_TIMEOUT,
        )
        if resp.ok:
            return
        raise RuntimeError(f"写入失败 {table}: {resp.status_code} {resp.text[:200]}")
    retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


def sb_insert_ignore(table, rows):
    """插入，主键冲突则忽略（Prefer: return=minimal + resolution=ignore-duplicates）"""
    if not rows:
        return
    headers = {**_sb_headers(), "Prefer": "return=minimal,resolution=ignore-duplicates"}

    def _do():
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/{table}",
            json=rows, headers=headers, timeout=REQUEST_TIMEOUT,
        )
        if resp.ok:
            return
        raise RuntimeError(f"写入失败 {table}: {resp.status_code} {resp.text[:200]}")
    retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


def sb_delete(table, params):
    headers = {**_sb_headers(), "Prefer": "return=minimal"}

    def _do():
        resp = requests.delete(
            f"{SUPABASE_URL}/rest/v1/{table}", params=params,
            headers=headers, timeout=REQUEST_TIMEOUT,
        )
        if resp.ok:
            return
        raise RuntimeError(f"删除失败 {table}: {resp.text[:200]}")
    retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


def chunked(items, size):
    for i in range(0, len(items), size):
        yield items[i:i + size]


# ============================================================
# 步骤 1：从 6 册 JSON 收集所有 SUCCESS 词条
# ============================================================

BOOKS = [
    "新标日初级上册",
    "新标日初级下册",
    "新标日中级上册",
    "新标日中级下册",
    "新标日高级上册",
    "新标日高级下册",
]

def collect_success_words(project_root):
    """
    返回 dict: word_id -> word_data (只保留 SUCCESS 状态的最佳来源)
    """
    best = {}   # word_id -> word dict
    for book_name in BOOKS:
        path = project_root / GENERATED_DIR / f"{book_name}.json"
        if not path.exists():
            print(f"   [跳过] {book_name} - 文件不存在")
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        count = 0
        for w in data.get("words", []):
            status = w.get("_source_meta", {}).get("generation_status", "")
            if status != "SUCCESS":
                continue
            word_id = w.get("_word_id")
            if not word_id:
                continue
            # 已有更好来源则跳过（按书顺序，先遇到的优先；可根据需要改为后者覆盖前者）
            if word_id not in best:
                best[word_id] = w
                count += 1
        print(f"   {book_name}: 收集 SUCCESS {count} 条")
    return best


# ============================================================
# 步骤 2：查询云端需要修复的 word_id
# ============================================================

def fetch_empty_word_ids(candidate_ids):
    """
    对候选 word_ids 批量查询云端 word_details，
    返回 rich_content.meanings 为空的 word_id 集合。
    """
    empty_ids = set()
    candidates = list(candidate_ids)
    total = len(candidates)
    checked = 0
    for batch in chunked(candidates, UPLOAD_READ_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        rows = sb_read("word_details", {"word_id": in_filter, "select": "word_id,rich_content"})
        for row in rows:
            rc = row.get("rich_content") or {}
            if not rc.get("meanings"):
                empty_ids.add(row["word_id"])
        checked += len(batch)
        if checked % 400 == 0 or checked == total:
            print(f"   已检查: {checked}/{total}，发现空 meanings: {len(empty_ids)}")
    return empty_ids


def fetch_missing_in_cloud(candidate_ids):
    """返回在云端 word_details 表中根本不存在的 word_id（需要 INSERT）。"""
    existing = set()
    for batch in chunked(list(candidate_ids), UPLOAD_READ_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        rows = sb_read("word_details", {"word_id": in_filter, "select": "word_id"})
        for row in rows:
            existing.add(row["word_id"])
    return set(candidate_ids) - existing


# ============================================================
# 步骤 3：构建修复行
# ============================================================

def build_repair_rows(word_ids_to_fix, success_map, dry_run=False):
    words_rows = []
    details_rows = []
    examples_rows = []
    skipped = 0

    for word_id in word_ids_to_fix:
        w = success_map.get(word_id)
        if not w:
            skipped += 1
            continue

        basic = w.get("1_basic_info", {})
        meanings = w.get("2_meanings_and_nuance", [])
        primary_meaning = meanings[0].get("definition", "") if meanings else ""

        words_rows.append({
            "id": word_id,
            "word": basic.get("word", ""),
            "reading": basic.get("reading", ""),
            "romaji": basic.get("romaji"),
            "pitch_accent": basic.get("pitch_accent"),
            "jlpt_level": basic.get("jlpt_level"),
            "part_of_speech": basic.get("part_of_speech", ""),
            "transitivity": basic.get("transitivity"),
            "primary_meaning": primary_meaning,
        })

        meta = w.get("_source_meta", {})
        rich_content = {
            "meanings": meanings,
            "grammar_rules": w.get("3_critical_grammar_rules", {}).get("associated_particles"),
            "conjugations": w.get("4_conjugations"),
            "synonyms_antonyms": w.get("7_synonyms_and_antonyms"),
            "collocations": w.get("8_collocations_and_phrases"),
            "common_mistakes": w.get("9_common_mistakes_and_usage_notes"),
            "_source_meta": meta,
        }
        details_rows.append({"word_id": word_id, "rich_content": rich_content})

        ex_order = 0
        for ex in w.get("6_example_sentences", []):
            ex_id = make_uuid("example", f"{word_id}:{ex_order}")
            examples_rows.append({
                "id": ex_id,
                "word_id": word_id,
                "japanese": ex.get("japanese", ""),
                "chinese": ex.get("chinese", ""),
                "has_audio": False,
                "sort_order": ex_order,
            })
            ex_order += 1

    if skipped:
        print(f"   ⚠️ {skipped} 条在本地 SUCCESS 中找不到（已跳过）")
    return words_rows, details_rows, examples_rows


# ============================================================
# 主流程
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="修复被 CLOUD_REFERENCE 覆盖的云端数据")
    parser.add_argument("--dry-run", action="store_true", help="预览模式，不实际写入")
    args = parser.parse_args()

    project_root = config.PROJECT_ROOT

    print("=" * 60)
    print("  云端数据修复工具")
    print("  修复被 CLOUD_REFERENCE UPSERT 覆盖的 words/word_details/word_examples")
    print("=" * 60)

    # --- 步骤 1：收集本地所有 SUCCESS 词 ---
    print("\n[1/4] 扫描本地 6 册 SUCCESS 数据...")
    success_map = collect_success_words(project_root)
    print(f"   共 {len(success_map)} 个唯一 SUCCESS word_id")

    # --- 步骤 2：查询云端需要修复的词 ---
    print("\n[2/4] 查询云端 word_details，定位 meanings 为空的词...")
    empty_ids = fetch_empty_word_ids(list(success_map.keys()))
    print(f"   需要修复: {len(empty_ids)} 条")

    # 同时检查本地 success_map 中完全不在云端 word_details 的词（INSERT 而非 UPDATE）
    print("\n[2b/4] 检查云端 word_details 中完全缺失的词...")
    missing_ids = fetch_missing_in_cloud(list(success_map.keys()))
    missing_ids = missing_ids & set(success_map.keys())  # 只处理我们有 SUCCESS 数据的
    print(f"   云端完全缺失: {len(missing_ids)} 条")

    all_fix_ids = empty_ids | missing_ids
    if not all_fix_ids:
        print("\n✅ 没有需要修复的词条，云端数据已经完整！")
        return

    print(f"\n   合计需修复: {len(all_fix_ids)} 条")

    # --- 步骤 3：构建修复行 ---
    print("\n[3/4] 构建修复数据...")
    words_rows, details_rows, examples_rows = build_repair_rows(all_fix_ids, success_map, args.dry_run)
    print(f"   words:    {len(words_rows)}")
    print(f"   details:  {len(details_rows)}")
    print(f"   examples: {len(examples_rows)}")

    if args.dry_run:
        print("\n🔍 [DRY RUN] 预览完成，未执行任何写入。")
        print("   示例修复词：")
        for row in words_rows[:5]:
            print(f"     - {row['word']} ({row['reading']}) jlpt={row['jlpt_level']} pos={row['part_of_speech']}")
        return

    # --- 步骤 4：写入云端 ---
    print("\n[4/4] 写入云端...")

    # 4a: 修复 words 表基础字段（UPSERT，不更新 has_audio）
    print("   4a: 修复 words 基础字段...")
    for batch in chunked(words_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("words", batch, on_conflict="id")

    # 4b: 修复 word_details（UPSERT ON CONFLICT word_id）
    print("   4b: 修复 word_details...")
    for batch in chunked(details_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("word_details", batch, on_conflict="word_id")

    # 4c: 修复 word_examples（先删后插）
    print("   4c: 修复 word_examples...")
    fix_word_ids = [r["word_id"] for r in details_rows]
    for batch in chunked(fix_word_ids, UPLOAD_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        sb_delete("word_examples", {"word_id": in_filter})
    for batch in chunked(examples_rows, UPLOAD_BATCH_SIZE):
        sb_insert_ignore("word_examples", batch)

    # --- 验证 ---
    print("\n🔍 验证修复结果（抽样检查 10 条）...")
    sample_ids = list(all_fix_ids)[:10]
    in_filter = "in.(" + ",".join(sample_ids) + ")"
    rows = sb_read("word_details", {"word_id": in_filter, "select": "word_id,rich_content"})
    ok = sum(1 for r in rows if r.get("rich_content", {}).get("meanings"))
    print(f"   抽样 {len(rows)} 条，meanings 非空: {ok} 条")

    print(f"\n{'=' * 60}")
    print(f"  ✅ 修复完成！")
    print(f"  修复 words:    {len(words_rows)} 条")
    print(f"  修复 details:  {len(details_rows)} 条")
    print(f"  修复 examples: {len(examples_rows)} 条")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
