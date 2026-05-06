#!/usr/bin/env python3
"""
单词数据上传器 (v3.0)
====================
将已校验的单词数据和音频上传到 Supabase + R2。

特性:
  - 上传前自动校验
  - 分阶段写入 + 每步验证
  - R2 并发上传 + 重试 + checkpoint
  - 上传后 count 校验
  - --dry-run 预览
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import (
    SUPABASE_URL, SOURCES_DIR, GENERATED_DIR, CHECKPOINTS_DIR,
    UPLOAD_BATCH_SIZE, UPLOAD_READ_BATCH_SIZE, R2_UPLOAD_WORKERS,
    R2_BUCKET_NAME, REQUEST_TIMEOUT, CONJUGATION_KEYS,
    make_uuid,
)
from _vocab_common.retry import retry_call
from _vocab_common.checkpoint import Checkpoint

import requests


KANA_ONLY_RE = re.compile(r"[\u3040-\u309F\u30A0-\u30FFー・\s]+")


def _reading_required(word):
    return not KANA_ONLY_RE.fullmatch(str(word or ""))


# ============================================================
# Supabase 操作（带统一重试）
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
        raise RuntimeError(f"DB读取失败 {table}: {resp.status_code} {resp.text[:200]}")
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
        # PostgREST schema cache 缺字段 → 自动移除
        if "PGRST204" in resp.text and "Could not find the '" in resp.text:
            m = re.search(r"Could not find the '([^']+)' column", resp.text)
            if m:
                col = m.group(1)
                cleaned = [{k: v for k, v in r.items() if k != col} for r in rows]
                resp2 = requests.post(
                    f"{SUPABASE_URL}/rest/v1/{table}", params={"on_conflict": on_conflict},
                    json=cleaned, headers=headers, timeout=REQUEST_TIMEOUT,
                )
                if resp2.ok:
                    return
        raise RuntimeError(f"DB写入失败 {table}: {resp.status_code} {resp.text[:200]}")

    retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


def sb_insert_many(table, rows):
    if not rows:
        return
    headers = {**_sb_headers(), "Prefer": "return=minimal"}

    def _try_batch():
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/{table}", json=rows,
            headers=headers, timeout=REQUEST_TIMEOUT,
        )
        if resp.ok:
            return
        # 主键冲突 → 逐条插入
        if "23505" in resp.text:
            for row in rows:
                _try_single(row)
            return
        raise RuntimeError(f"DB批量写入失败 {table}: {resp.text[:200]}")

    def _try_single(row):
        resp = requests.post(
            f"{SUPABASE_URL}/rest/v1/{table}", json=row,
            headers=headers, timeout=REQUEST_TIMEOUT,
        )
        if resp.ok or "23505" in resp.text:
            return
        raise RuntimeError(f"DB单条写入失败 {table}: {resp.text[:200]}")

    retry_call(_try_batch, max_retries=8, base_delay=2.0, max_delay=15.0)


def sb_patch_many(table, ids, patch, batch_size=100):
    """批量 PATCH （相同字段值），用 id=in.(...) 过滤，不影响其他字段。"""
    if not ids or not patch:
        return
    headers = {**_sb_headers(), "Prefer": "return=minimal"}
    for chunk in chunked(list(ids), batch_size):
        id_list = ",".join(chunk)

        def _do(id_list=id_list):
            resp = requests.patch(
                f"{SUPABASE_URL}/rest/v1/{table}", params={"id": f"in.({id_list})"},
                json=patch, headers=headers, timeout=REQUEST_TIMEOUT,
            )
            if resp.ok:
                return
            raise RuntimeError(f"DB批量更新失败 {table}: {resp.status_code} {resp.text[:200]}")

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
        raise RuntimeError(f"DB删除失败 {table}: {resp.text[:200]}")

    retry_call(_do, max_retries=8, base_delay=2.0, max_delay=15.0)


# ============================================================
# R2 上传
# ============================================================

def r2_upload(r2_path, local_file, worker_dir):
    env = os.environ.copy()
    token = config.cloudflare_api_token()
    if token:
        env["CLOUDFLARE_API_TOKEN"] = token

    def _do():
        result = subprocess.run(
            ["npx", "wrangler", "r2", "object", "put",
             f"{R2_BUCKET_NAME}/{r2_path}", "--file", str(local_file), "--remote"],
            cwd=worker_dir, capture_output=True, text=True, env=env, timeout=120,
        )
        if result.returncode == 0:
            return
        raise RuntimeError(f"R2上传失败: {result.stderr[:120]}")

    retry_call(_do, max_retries=6, base_delay=5.0, max_delay=30.0)


# ============================================================
# 辅助
# ============================================================

def chunked(items, size):
    for i in range(0, len(items), size):
        yield items[i:i + size]


def fetch_existing_words(word_ids):
    existing = {}
    unique = list(dict.fromkeys(word_ids))
    for batch in chunked(unique, UPLOAD_READ_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        rows = sb_read("words", {"select": "id,has_audio", "id": in_filter})
        for row in rows:
            existing[row["id"]] = row
    return existing


def fetch_book_word_ids(book_id):
    rows = sb_read("lesson_word_map", {"book_id": f"eq.{book_id}", "select": "word_id"})
    return {row.get("word_id") for row in rows if row.get("word_id")}


def fetch_referenced_word_ids(word_ids):
    if not word_ids:
        return set()
    referenced = set()
    unique = list(dict.fromkeys(word_ids))
    for batch in chunked(unique, UPLOAD_READ_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        rows = sb_read("lesson_word_map", {"word_id": in_filter, "select": "word_id"})
        for row in rows:
            if row.get("word_id"):
                referenced.add(row["word_id"])
    return referenced


def delete_words_bundle(word_ids):
    if not word_ids:
        return
    for batch in chunked(list(word_ids), UPLOAD_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        sb_delete("word_examples", {"word_id": in_filter})
        sb_delete("word_details", {"word_id": in_filter})
        sb_delete("words", {"id": in_filter})


# ============================================================
# 主入口
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="单词数据上传器")
    parser.add_argument("--book-name", required=True, help="辞书名")
    parser.add_argument("--dry-run", action="store_true", help="预览模式")
    parser.add_argument("--skip-validate", action="store_true", help="跳过校验")
    parser.add_argument("--resume", action="store_true", help="断点续传")
    args = parser.parse_args()

    project_root = config.PROJECT_ROOT
    generated_file = project_root / GENERATED_DIR / f"{args.book_name}.json"
    source_dir = project_root / SOURCES_DIR / args.book_name
    audio_dir = source_dir / "audios"
    worker_dir = project_root / "api" / "workers"
    checkpoint_dir = project_root / CHECKPOINTS_DIR
    r2_checkpoint_file = checkpoint_dir / f"r2_{args.book_name}.json"

    if not generated_file.exists():
        print(f"❌ 找不到生成文件: {generated_file}")
        sys.exit(1)

    # 自动校验
    if not args.skip_validate:
        print("📋 运行数据校验...")
        validator = project_root / ".agents" / "skills" / "vocab-validator" / "scripts" / "validate.py"
        result = subprocess.run(
            [sys.executable, str(validator), "--book-name", args.book_name],
            cwd=project_root,
        )
        if result.returncode == 1:
            print("\n❌ 数据校验失败，请先修复 ERROR 后再上传。")
            sys.exit(1)
        elif result.returncode == 2:
            print("\n⚠️ 数据有警告，继续上传...\n")

    # 加载数据
    with open(generated_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    file_meta = data.get("_meta", {})
    words = data.get("words", [])
    book_id = file_meta.get("book_id")
    book_title = file_meta.get("book_title", args.book_name)

    if not book_id:
        print("❌ 生成文件缺少 _meta.book_id")
        sys.exit(1)

    # 过滤有效词条（排除 FAILED_SKIP / CLOUD_REFERENCE 中无数据的词条）
    valid_words = []
    for w in words:
        status = w.get("_source_meta", {}).get("generation_status", "")
        basic = w.get("1_basic_info", {})
        if not basic.get("word"):
            continue
        if _reading_required(basic.get("word")) and not basic.get("reading"):
            continue
        if status == "FAILED_SKIP":
            continue
        valid_words.append(w)

    print(f"\n📦 准备上传: {args.book_name}")
    print(f"   辞书: {book_title}")
    print(f"   有效词条: {len(valid_words)} / {len(words)}")

    old_book_word_ids = fetch_book_word_ids(book_id)
    if old_book_word_ids:
        print(f"   现有云端 book 词条: {len(old_book_word_ids)}")

    # 构建 DB 行
    all_word_ids = []
    words_rows = []
    details_rows = []
    examples_rows = []
    map_rows = []
    lessons_seen = {}
    seen_word_ids = set()
    seen_map_ids = set()
    cloud_ref_word_ids = set()  # CLOUD_REFERENCE 词的 word_id，上传时跳过 words/details/examples

    for w in valid_words:
        word_id = w.get("_word_id")
        if not word_id:
            basic = w.get("1_basic_info", {})
            word_id = make_uuid("word", f"{basic['word'].strip()}:{basic['reading'].strip()}")

        all_word_ids.append(word_id)

        lesson = w.get("_lesson", {})
        lesson_id = lesson.get("id") if lesson else None

        # Lesson 收集
        if lesson_id and lesson_id not in lessons_seen:
            lessons_seen[lesson_id] = {
                "id": lesson_id,
                "book_id": book_id,
                "lesson_number": lesson.get("number", 0),
                "title": lesson.get("title", ""),
                "word_count": 0,
                "sort_order": lesson.get("number", 0),
            }
        if lesson_id:
            lessons_seen[lesson_id]["word_count"] += 1

        # Lesson-Word Map（同一 book+lesson+word 组合去重，避免批次内重复触发 ON CONFLICT 错误）
        map_id = make_uuid("map", f"{book_id}:{lesson_id}:{word_id}")
        if map_id not in seen_map_ids:
            seen_map_ids.add(map_id)
            map_rows.append({
                "id": map_id,
                "book_id": book_id,
                "lesson_id": lesson_id,
                "word_id": word_id,
                "sort_order": w.get("_sort_order", 0),
                "book_sort_order": w.get("_book_sort_order", 0),
            })

        # 同一 word 只写一次 words/details/examples
        if word_id in seen_word_ids:
            continue
        seen_word_ids.add(word_id)

        # CLOUD_REFERENCE：该词在云端已有完整数据，只写 lesson_word_map，不覆盖 words/details/examples
        status = w.get("_source_meta", {}).get("generation_status", "")
        if status == "CLOUD_REFERENCE":
            cloud_ref_word_ids.add(word_id)
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
            "has_audio": False,  # 后续更新
        })

        meta = w.get("_source_meta", {})
        rich_content = {
            "meanings": w.get("2_meanings_and_nuance"),
            "grammar_rules": w.get("3_critical_grammar_rules", {}).get("associated_particles"),
            "conjugations": w.get("4_conjugations"),
            "synonyms_antonyms": w.get("7_synonyms_and_antonyms"),
            "collocations": w.get("8_collocations_and_phrases"),
            "common_mistakes": w.get("9_common_mistakes_and_usage_notes"),
        }
        if meta:
            rich_content["_source_meta"] = meta

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

    lesson_rows = list(lessons_seen.values())
    book_rows = [{
        "id": book_id,
        "title": book_title,
        "has_lessons": True,
        "word_count": len(valid_words),
    }]

    print(f"\n   📊 统计:")
    print(f"      books:    {len(book_rows)}")
    print(f"      lessons:  {len(lesson_rows)}")
    print(f"      words:    {len(words_rows)}")
    print(f"      details:  {len(details_rows)}")
    print(f"      examples: {len(examples_rows)}")
    print(f"      map:      {len(map_rows)}")

    if args.dry_run:
        print(f"\n🔍 [DRY RUN] 预览完成，未执行任何写入。")
        return

    # === 阶段 1: 查询已有数据 ===
    print(f"\n[1/6] 查询云端已有数据...")
    existing_words = fetch_existing_words(all_word_ids)
    existing_audio = {wid for wid, row in existing_words.items() if row.get("has_audio")}
    print(f"   已存在: {len(existing_words)} | 已有音频: {len(existing_audio)}")

    # === 阶段 2: 清理旧关联 ===
    print(f"[2/6] 清理旧关联...")
    sb_delete("lesson_word_map", {"book_id": f"eq.{book_id}"})
    sb_delete("lessons", {"book_id": f"eq.{book_id}"})
    # 删除旧例句（跳过 CLOUD_REFERENCE 词，避免删除其他书已写入的例句）
    non_cloud_ref_ids = seen_word_ids - cloud_ref_word_ids
    for batch in chunked(list(non_cloud_ref_ids), UPLOAD_BATCH_SIZE):
        in_filter = "in.(" + ",".join(batch) + ")"
        sb_delete("word_examples", {"word_id": in_filter})

    # === 阶段 3: 写入 books + lessons ===
    print(f"[3/6] 写入 books + lessons...")
    sb_upsert("books", book_rows)
    for batch in chunked(lesson_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("lessons", batch)

    # 验证
    db_lessons = sb_read("lessons", {"book_id": f"eq.{book_id}", "select": "id"})
    if len(db_lessons) != len(lesson_rows):
        print(f"   ⚠️ lessons 数量不一致: 期望 {len(lesson_rows)}, 实际 {len(db_lessons)}")

    # === 阶段 4: 写入 words + details + examples ===
    print(f"[4/6] 写入 words + details + examples...")
    for batch in chunked(words_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("words", batch)
    for batch in chunked(details_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("word_details", batch, on_conflict="word_id")
    for batch in chunked(examples_rows, UPLOAD_BATCH_SIZE):
        sb_insert_many("word_examples", batch)

    # === 阶段 5: 写入 lesson_word_map ===
    print(f"[5/6] 写入 lesson_word_map...")
    for batch in chunked(map_rows, UPLOAD_BATCH_SIZE):
        sb_upsert("lesson_word_map", batch, on_conflict="id")

    removed_word_ids = old_book_word_ids - seen_word_ids
    if removed_word_ids:
        print(f"[5.5/6] 清理下线词条... ({len(removed_word_ids)} 条)")
        still_referenced = fetch_referenced_word_ids(removed_word_ids)
        orphaned_word_ids = removed_word_ids - still_referenced
        if orphaned_word_ids:
            delete_words_bundle(orphaned_word_ids)
            print(f"   已删除孤立 words/details/examples: {len(orphaned_word_ids)}")
        else:
            print("   无需删除孤立词条")

    # === 阶段 6: R2 音频上传 ===
    print(f"[6/6] 上传音频到 R2...")
    r2_ckpt = Checkpoint(r2_checkpoint_file)
    r2_done = r2_ckpt.get_set("uploaded")

    audio_jobs = []
    for w in valid_words:
        word_id = w.get("_word_id")
        if not word_id:
            basic = w.get("1_basic_info", {})
            word_id = make_uuid("word", f"{basic['word'].strip()}:{basic['reading'].strip()}")

        if word_id in existing_audio or word_id in r2_done:
            continue

        meta = w.get("_source_meta", {})
        moji_id = meta.get("moji_word_id")
        if moji_id:
            audio_file = audio_dir / f"{moji_id}.mp3"
            if audio_file.exists() and audio_file.stat().st_size > 0:
                audio_jobs.append((word_id, f"audio/words/{word_id}/main.mp3", audio_file))

    cf_token = config.cloudflare_api_token()
    if audio_jobs and not cf_token:
        print(f"   ⚠️ 未配置 CLOUDFLARE_API_TOKEN，跳过 {len(audio_jobs)} 条音频上传")
        audio_jobs = []

    uploaded_ids = set()
    failed_audio = 0

    if audio_jobs:
        print(f"   待上传: {len(audio_jobs)} 条音频 (并发 {R2_UPLOAD_WORKERS})")
        with ThreadPoolExecutor(max_workers=R2_UPLOAD_WORKERS) as executor:
            future_map = {
                executor.submit(r2_upload, r2_path, audio_file, worker_dir): wid
                for wid, r2_path, audio_file in audio_jobs
            }
            done_count = 0
            for future in as_completed(future_map):
                wid = future_map[future]
                try:
                    future.result()
                    uploaded_ids.add(wid)
                except Exception as e:
                    failed_audio += 1
                    print(f"   ⚠️ 音频上传失败: {wid} ({e})")
                done_count += 1
                if done_count % 20 == 0 or done_count == len(audio_jobs):
                    print(f"   进度: {done_count}/{len(audio_jobs)}")

        # 保存 checkpoint
        r2_ckpt.batch_save_set("uploaded", uploaded_ids)

    # 更新 has_audio 标记
    audio_word_ids = existing_audio | uploaded_ids | r2_done
    if audio_word_ids:
        batch_ids = list(audio_word_ids & seen_word_ids)
        print(f"   更新 has_audio: {len(batch_ids)} 条...")
        sb_patch_many("words", batch_ids, {"has_audio": True})

    # === 上传后校验 ===
    print(f"\n📋 上传后校验...")
    db_words = sb_read("words", {
        "id": f"in.({','.join(list(seen_word_ids)[:500])})",
        "select": "id",
    })
    db_map = sb_read("lesson_word_map", {"book_id": f"eq.{book_id}", "select": "id"})

    print(f"   words:    期望 {len(words_rows)}, 实际 {len(db_words)} (抽样 500)")
    print(f"   map:      期望 {len(map_rows)}, 实际 {len(db_map)}")

    # 最终报告
    print(f"\n{'='*60}")
    print(f"  ✅ 上传完成!")
    print(f"  总词条:       {len(valid_words)}")
    print(f"  唯一单词:     {len(seen_word_ids)}")
    print(f"  课数:         {len(lesson_rows)}")
    print(f"  音频上传:     {len(uploaded_ids)} 成功, {failed_audio} 失败")
    print(f"  已有音频:     {len(existing_audio)}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
