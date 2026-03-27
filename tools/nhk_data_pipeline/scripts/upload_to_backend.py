#!/usr/bin/env python3
"""
upload_to_backend.py
将本地 data/{id}/processed.json 上传到 Supabase + R2

使用方式:
  # 上传所有新文章（增量，默认）
  python scripts/upload_to_backend.py

  # 强制覆盖所有已存在的文章
  python scripts/upload_to_backend.py --force

  # 只上传指定 ID
  python scripts/upload_to_backend.py --id ne2026031311469

  # 上传前先检查哪些文章需要上传（dry run）
  python scripts/upload_to_backend.py --dry-run
"""

import os
import json
import sys
import argparse
import subprocess
from datetime import datetime, timezone
from pathlib import Path

# -------------------------------------------------------
# 配置（从环境变量读取敏感信息）
# -------------------------------------------------------
SUPABASE_URL = os.environ.get(
    "SUPABASE_URL",
    "https://eecfrzvutrhftwvyebpq.supabase.co"
)
# 必须设置 SUPABASE_SERVICE_KEY 环境变量（sb_secret_...）
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

# Cloudflare R2 配置（使用 wrangler CLI 上传，无需 API 密钥）
R2_BUCKET_NAME = "breeze-jp"

SCRIPT_DIR = Path(__file__).parent
PIPELINE_DIR = SCRIPT_DIR.parent
DATA_DIR = PIPELINE_DIR / "data"


# -------------------------------------------------------
# Supabase REST API 调用封装
# -------------------------------------------------------
def supabase_headers() -> dict:
    """构建 Supabase 请求头"""
    if not SUPABASE_SERVICE_KEY:
        print("❌ 环境变量 SUPABASE_SERVICE_KEY 未设置")
        print("   请先执行: export SUPABASE_SERVICE_KEY='sb_secret_...'")
        sys.exit(1)
    return {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",  # 不返回数据，节省带宽
    }


def supabase_get(path: str, params: dict = None) -> list:
    """GET 请求到 Supabase REST API"""
    import urllib.request
    import urllib.parse

    url = f"{SUPABASE_URL}/rest/v1{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    req = urllib.request.Request(url, headers=supabase_headers())
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        print(f"  ❌ Supabase GET {path} 失败: {e}")
        return []


def supabase_upsert(table: str, data: dict) -> bool:
    """UPSERT 到 Supabase 表（按 PRIMARY KEY 冲突则更新）"""
    import urllib.request

    url = f"{SUPABASE_URL}/rest/v1/{table}"
    body = json.dumps(data, ensure_ascii=False).encode("utf-8")

    headers = supabase_headers()
    headers["Prefer"] = "resolution=merge-duplicates,return=minimal"

    req = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status in (200, 201, 204)
    except Exception as e:
        print(f"  ❌ Supabase UPSERT {table} 失败: {e}")
        return False


def get_existing_article_ids() -> set:
    """获取 Supabase 中已存在的所有文章 ID"""
    rows = supabase_get("/articles", {"select": "id"})
    return {row["id"] for row in rows}


# -------------------------------------------------------
# Cloudflare R2 上传（使用 wrangler CLI）
# -------------------------------------------------------
def upload_audio_to_r2(article_id: str, mp3_path: Path) -> str:
    """上传 mp3 到 R2，返回访问 URL"""
    r2_key = f"audio/audio_articles/{article_id}.mp3"

    # 检查 wrangler 是否安装
    result = subprocess.run(
        ["wrangler", "--version"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  ⚠️  wrangler 未安装，跳过音频上传")
        return ""

    print(f"  ☁️  上传音频到 R2: {r2_key}")
    result = subprocess.run(
        ["wrangler", "r2", "object", "put",
         f"{R2_BUCKET_NAME}/{r2_key}",
         "--file", str(mp3_path),
         "--content-type", "audio/mpeg"],
        capture_output=True, text=True,
        cwd=PIPELINE_DIR.parent.parent / "backend" / "workers"  # 项目根 → backend/workers
    )

    if result.returncode == 0:
        # 音频通过 Workers API 代理访问
        audio_url = f"https://api.binary-dracula.com/api/v1/audio/{article_id}"
        print(f"  ✅ 音频上传成功 → {audio_url}")
        return audio_url
    else:
        print(f"  ❌ 音频上传失败: {result.stderr.strip()}")
        return ""


# -------------------------------------------------------
# 主逻辑：处理单篇文章
# -------------------------------------------------------
def upload_article(article_id: str, force: bool = False,
                   dry_run: bool = False, existing_ids: set = None) -> bool:
    """将一篇文章的 processed.json 上传到 Supabase"""

    processed_path = DATA_DIR / article_id / "processed.json"
    if not processed_path.exists():
        print(f"  ⚠️  processed.json 不存在，跳过: {article_id}")
        return False

    # 检查是否已存在（增量跳过）
    if not force and existing_ids is not None and article_id in existing_ids:
        print(f"  ⏭️  已存在，跳过: {article_id}")
        return False

    with open(processed_path, "r", encoding="utf-8") as f:
        processed = json.load(f)

    if dry_run:
        print(f"  [DRY RUN] 将上传: {article_id}")
        return True

    # ---- 1. 处理音频 ----
    audio_url = ""
    mp3_path = DATA_DIR / article_id / f"{article_id}.mp3"
    if mp3_path.exists():
        audio_url = upload_audio_to_r2(article_id, mp3_path)
    else:
        print(f"  ℹ️  无音频文件，跳过 R2 上传")

    # ---- 2. 计算 duration_ms ----
    sentences = processed.get("sentences", [])
    duration_ms = 0
    if sentences:
        last_end = sentences[-1].get("end_ms")
        if last_end:
            duration_ms = last_end

    # ---- 3. 解析发布时间 ----
    raw_time = processed.get("time", "")
    try:
        published_at = datetime.fromisoformat(
            raw_time.replace(" ", "T")
        ).isoformat()
    except Exception:
        published_at = datetime.now(timezone.utc).isoformat()

    # ---- 4. 构建 articles 记录 ----
    article_record = {
        "id": processed["id"],
        "title": processed.get("title", ""),
        "clean_title": processed.get("clean_title", ""),
        "published_at": published_at,
        "audio_url": audio_url,
        "duration_ms": duration_ms,
        "sentence_count": len(sentences),
        "is_archived": False,
    }

    # ---- 5. 构建 article_details 记录（完整 items）----
    items = []
    for i, sentence in enumerate(sentences):
        item = {
            "text": sentence.get("original_text_with_ruby", sentence.get("text", "")),
            "translation": sentence.get("translation", ""),
            "start_ms": sentence.get("start_ms"),
            "end_ms": sentence.get("end_ms"),
            "index": i,
            "words": sentence.get("words", []),
        }
        items.append(item)

    detail_record = {
        "article_id": processed["id"],
        "items": items,
    }

    # ---- 6. 写入 Supabase ----
    print(f"  📤 写入 articles...")
    ok1 = supabase_upsert("articles", article_record)
    print(f"  📤 写入 article_details ({len(items)} 句)...")
    ok2 = supabase_upsert("article_details", detail_record)

    if ok1 and ok2:
        print(f"  ✅ 上传完成: {article_id}")
        return True
    else:
        print(f"  ❌ 上传失败: {article_id}")
        return False


# -------------------------------------------------------
# 主程序
# -------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="上传 NHK 新闻数据到 Supabase + R2")
    parser.add_argument("--force", action="store_true",
                        help="强制覆盖已存在的文章")
    parser.add_argument("--dry-run", action="store_true",
                        help="只显示将要上传的文章，不实际上传")
    parser.add_argument("--id", type=str, default=None,
                        help="只上传指定 ID 的文章")
    args = parser.parse_args()

    print("🚀 BreezeJP 数据上传工具")
    print(f"   Supabase: {SUPABASE_URL}")
    print(f"   R2 Bucket: {R2_BUCKET_NAME}")
    print()

    if args.dry_run:
        print("⚠️  DRY RUN 模式，不会实际上传\n")

    # 确定要处理的文章列表
    if args.id:
        article_ids = [args.id]
    else:
        # 扫描 data/ 目录下有 processed.json 的文章
        article_ids = sorted([
            d.name for d in DATA_DIR.iterdir()
            if d.is_dir() and (d / "processed.json").exists()
        ])

    print(f"📂 发现 {len(article_ids)} 篇已处理文章")

    # 获取已存在的文章 ID（用于增量判断）
    existing_ids = set()
    if not args.force and not args.dry_run:
        print("🔍 查询 Supabase 已存在文章...")
        existing_ids = get_existing_article_ids()
        new_count = len([a for a in article_ids if a not in existing_ids])
        print(f"   已存在: {len(existing_ids)} 篇 | 待上传: {new_count} 篇\n")

    # 逐篇处理
    success = 0
    skip = 0
    fail = 0

    for i, article_id in enumerate(article_ids, 1):
        print(f"[{i}/{len(article_ids)}] {article_id}")
        result = upload_article(
            article_id,
            force=args.force,
            dry_run=args.dry_run,
            existing_ids=existing_ids
        )
        if result is True:
            success += 1
        elif result is False and article_id in (existing_ids or set()):
            skip += 1
        else:
            fail += 1

    print()
    print(f"🎉 完成！成功: {success} | 跳过: {skip} | 失败: {fail}")


if __name__ == "__main__":
    main()
