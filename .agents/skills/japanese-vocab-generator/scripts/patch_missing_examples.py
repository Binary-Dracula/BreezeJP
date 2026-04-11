"""
补丁脚本：补写 では 的 2 条缺失例句 (sort_order=1, sort_order=2)
"""
import json
import os
import time
import requests
from pathlib import Path

project_root = Path(__file__).resolve().parent.parent.parent.parent.parent

SUPABASE_URL = "https://eecfrzvutrhftwvyebpq.supabase.co"
SUPABASE_SERVICE_KEY = None

env_file = project_root / ".env"
with open(env_file) as f:
    for line in f:
        if line.strip().startswith("SUPABASE_SERVICE_KEY="):
            SUPABASE_SERVICE_KEY = line.strip().split("=", 1)[1].strip().strip("\"'")

assert SUPABASE_SERVICE_KEY, "未找到 SUPABASE_SERVICE_KEY"

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}

MISSING_ROWS = [
    {
        "id": "c4940b09-540a-502d-8445-ab05c8dfe96a",
        "word_id": "146bfaca-9a9a-5041-87ab-e640431c4cb8",
        "level": "Formal",
        "japanese": "では、会議[かいぎ]を始[はじ]めます。",
        "chinese": "那么，会议开始了。",
        "has_audio": False,
        "sort_order": 1,
    },
    {
        "id": "a13253ab-e482-5708-887a-c07374934dbd",
        "word_id": "146bfaca-9a9a-5041-87ab-e640431c4cb8",
        "level": "Formal",
        "japanese": "では、こちらで失礼[しつれい]いたします。",
        "chinese": "那么，我就在此告辞了。",
        "has_audio": False,
        "sort_order": 2,
    },
]


def insert_rows(table, rows):
    for attempt in range(3):
        try:
            resp = requests.post(
                f"{SUPABASE_URL}/rest/v1/{table}",
                headers=HEADERS,
                json=rows,
                timeout=20,
            )
            if resp.ok:
                return True
            # 23505 = duplicate key — already inserted
            if "23505" in resp.text:
                print(f"  ⚠️  已存在，跳过")
                return True
            print(f"  ⚠️  写库失败 (attempt {attempt+1}/3): {resp.status_code} {resp.text}")
        except Exception as e:
            print(f"  ⚠️  异常 (attempt {attempt+1}/3): {e}")
        time.sleep(2)
    return False


def main():
    print(f"📝 开始补写 {len(MISSING_ROWS)} 条缺失例句...")
    ok = insert_rows("word_examples", MISSING_ROWS)
    if ok:
        print("✅ 补写成功")
    else:
        print("❌ 补写失败，请检查错误信息")


if __name__ == "__main__":
    main()
