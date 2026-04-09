import argparse
import json
import os
import subprocess
import sys
import time
import uuid
import requests
from pathlib import Path

project_root = Path(__file__).resolve().parent.parent.parent.parent.parent

env_file = project_root / ".env"
SUPABASE_SERVICE_KEY = None
if env_file.exists():
    with open(env_file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SUPABASE_SERVICE_KEY="):
                SUPABASE_SERVICE_KEY = line.split("=", 1)[1].strip().strip('"\'')
            elif line.startswith("SUPABASE_SERVICE_KEY"):
                parts = line.split("=", 1)
                if len(parts) == 2 and parts[0].strip() == "SUPABASE_SERVICE_KEY":
                    SUPABASE_SERVICE_KEY = parts[1].strip().strip('"\'')

SUPABASE_URL = "https://eecfrzvutrhftwvyebpq.supabase.co"

def supabase_read(table, query_params):
    headers = {"apikey": SUPABASE_SERVICE_KEY, "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"}
    resp = requests.get(f"{SUPABASE_URL}/rest/v1/{table}", params=query_params, headers=headers)
    if not resp.ok: raise Exception(f"Read from {table} failed: {resp.text}")
    return resp.json()

def supabase_insert(table, data):
    headers = {
        "apikey": SUPABASE_SERVICE_KEY, "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json", "Prefer": "return=minimal"
    }
    for attempt in range(3):
        try:
            resp = requests.post(f"{SUPABASE_URL}/rest/v1/{table}", json=data, headers=headers)
            if resp.ok: return
            # 处理重复主键错误
            if "23505" in resp.text:
                # print(f"  ✨ [DB] {table} 记录已存在，跳过。")
                return
            print(f"  ⚠️ [DB] {table} 写入重试 ({attempt+1}/3): {resp.text}")
        except Exception as e:
            print(f"  ⚠️ [DB] {table} 写入异常重试 ({attempt+1}/3): {e}")
        time.sleep(2)
    raise Exception(f"Insert to {table} failed after retries")

def r2_upload(r2_path, local_file_path):
    worker_dir = project_root / "backend" / "workers"
    print(f"     ⛅️ [R2] 上传音频: {r2_path}")
    for attempt in range(3):
        result = subprocess.run(
            ["npx", "wrangler", "r2", "object", "put", f"breeze-jp/{r2_path}", "--file", str(local_file_path), "--remote"],
            cwd=worker_dir, capture_output=True, text=True
        )
        if result.returncode == 0: return
        print(f"     ⚠️ [R2] 上传重试 ({attempt+1}/3): {result.stderr}")
        time.sleep(3)
    raise Exception(f"R2 上传失败: {result.stderr}")

def get_deterministic_uuid(namespace_prefix, data_str):
    # 使用 NAMESPACE_DNS 作为基础，配合项目前缀生成确定性 UUID
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"breezejp:{namespace_prefix}:{data_str}"))

def get_or_create_book(title):
    book_id = get_deterministic_uuid("book", title)
    books = supabase_read("books", {"id": f"eq.{book_id}"})
    if books: return book_id
    
    supabase_insert("books", {"id": book_id, "title": title, "has_lessons": True, "word_count": 0})
    return book_id

def get_or_create_lesson(book_id, lesson_number, title):
    lesson_id = get_deterministic_uuid("lesson", f"{book_id}:{lesson_number}")
    lessons = supabase_read("lessons", {"id": f"eq.{lesson_id}"})
    if lessons: return lesson_id
    
    supabase_insert("lessons", {"id": lesson_id, "book_id": book_id, "lesson_number": lesson_number, "title": title, "word_count": 0})
    return lesson_id

def process_word(ai_json, audios_dir, book_id, lesson_id, sort_order):
    basic = ai_json.get("1_basic_info", {})
    meta = ai_json.get("_source_meta", {})
    
    word_text = basic.get("word", "").strip()
    reading_text = basic.get("reading", "").strip()
    
    if not word_text or not reading_text:
        print(f"  ⚠️ 警告：单词信息不完整，跳过。内容: {basic}")
        return

    # 重要：身份标识改为 word + reading
    word_id = get_deterministic_uuid("word", f"{word_text}:{reading_text}")
    
    # 检查是否已存在（幂等性）
    exists = supabase_read("words", {"id": f"eq.{word_id}"})
    if not exists:
        has_main_audio = False
        # 尝试使用 moji_id 获取音频（如果有的话）
        moji_id = meta.get("moji_word_id")
        if moji_id:
            audio_file = audios_dir / f"{moji_id}.mp3"
            if audio_file.exists():
                r2_upload(f"audio/words/{word_id}/main.mp3", audio_file)
                has_main_audio = True

        # 1. words
        meaning = ""
        meanings_list = ai_json.get("2_meanings_and_nuance", [])
        if meanings_list and isinstance(meanings_list, list) and len(meanings_list) > 0:
            meaning = meanings_list[0].get("definition", "")

        supabase_insert("words", {
            "id": word_id,
            "word": word_text,
            "reading": reading_text,
            "romaji": basic.get("romaji"),
            "pitch_accent": basic.get("pitch_accent"),
            "jlpt_level": basic.get("jlpt_level"),
            "part_of_speech": basic.get("part_of_speech", ""),
            "transitivity": basic.get("transitivity"),
            "primary_meaning": meaning,
            "has_audio": has_main_audio
        })

        # 2. word_details
        rich_content = {
            "meanings": ai_json.get("2_meanings_and_nuance"),
            "grammar_rules": ai_json.get("3_critical_grammar_rules", {}).get("associated_particles"),
            "conjugations": ai_json.get("4_conjugations"),
            "kanji_components": ai_json.get("5_kanji_components"),
            "synonyms_antonyms": ai_json.get("7_synonyms_and_antonyms"),
            "collocations": ai_json.get("8_collocations_and_phrases"),
            "common_mistakes": ai_json.get("9_common_mistakes_and_usage_notes"),
        }
        if meta:
            rich_content["_source_meta"] = meta
            
        supabase_insert("word_details", {
            "word_id": word_id,
            "rich_content": rich_content
        })

        # 3. word_examples
        ex_order = 0
        for ex in ai_json.get("6_example_sentences", []):
            ex_id = get_deterministic_uuid("example", f"{word_id}:{ex_order}")
            supabase_insert("word_examples", {
                "id": ex_id,
                "word_id": word_id,
                "level": ex.get("level", "Casual"),
                "japanese": ex.get("japanese", ""),
                "chinese": ex.get("chinese", ""),
                "has_audio": False,
                "sort_order": ex_order
            })
            ex_order += 1
    else:
        print(f"  ✨ 单词 [{word_text}] 已存在，仅建立关联。")

    # 4. lesson_word_map
    map_id = get_deterministic_uuid("map", f"{book_id}:{lesson_id}:{word_id}")
    supabase_insert("lesson_word_map", {
        "id": map_id,
        "book_id": book_id,
        "lesson_id": lesson_id,
        "word_id": word_id,
        "sort_order": sort_order
    })

def main():
    parser = argparse.ArgumentParser("Upload words to Supabase and R2")
    parser.add_argument("--ai-json", required=True, help="AI 生成的 JSON 结果如: xxx.json")
    parser.add_argument("--moji-json", required=True, help="原始抓取的 words.json 树形")
    parser.add_argument("--book-title", required=True, help="对应的书名")
    args = parser.parse_args()

    if not SUPABASE_SERVICE_KEY:
        print("❌ 错误：请在项目根目录 .env 中设置 SUPABASE_SERVICE_KEY 以便数据库写入（可以在 Supabase Dashboard API 中找到）。")
        sys.exit(1)

    ai_path = Path(args.ai_json)
    moji_path = Path(args.moji_json)
    
    if not ai_path.is_absolute(): ai_path = project_root / ai_path
    if not moji_path.is_absolute(): moji_path = project_root / moji_path
        
    audios_dir = moji_path.parent / "audios"

    print(f"📖 加载 AI 生成数据: {ai_path.name}")
    with open(ai_path, "r", encoding="utf-8") as f:
        ai_data_list = json.load(f)
        
    ai_dict = {}
    for item in ai_data_list:
        meta = item.get("_source_meta", {})
        moji_id = meta.get("moji_word_id")
        if moji_id:
            ai_dict[str(moji_id)] = item

    print(f"📖 加载 原始树形数据: {moji_path.name}")
    with open(moji_path, "r", encoding="utf-8") as f:
        moji_tree = json.load(f)

    print(f"📚 初始化书籍: {args.book_title}")
    book_id = get_or_create_book(args.book_title)

    global_lesson_num = 1
    total_uploaded = 0

    def traverse(node, path_titles):
        nonlocal global_lesson_num, total_uploaded
        
        if isinstance(node, dict):
            if "title" in node and "items" in node:
                new_path = path_titles + [node["title"]]
                word_sort_order = 0
                lesson_id = None
                
                # Check if this folder directly contains words
                has_words = any("wordId" in child for child in node["items"] if isinstance(child, dict))
                if has_words:
                    lesson_title = " / ".join(new_path)
                    print(f"\n📂 发现课节层级: {lesson_title} (Lesson {global_lesson_num})")
                    lesson_id = get_or_create_lesson(book_id, global_lesson_num, lesson_title)
                    global_lesson_num += 1
                
                for child in node["items"]:
                    if isinstance(child, dict) and "wordId" in child:
                        moji_id = str(child["wordId"])
                        if moji_id in ai_dict:
                            word_text = child.get('word', '')
                            print(f"  ➜ 正在上传单词 [{word_text}] ...")
                            process_word(ai_dict[moji_id], audios_dir, book_id, lesson_id, word_sort_order)
                            word_sort_order += 1
                            total_uploaded += 1
                        else:
                            print(f"  ⚠️ 跳过：在AI结果中未找到对应: {child.get('word', moji_id)}")
                    else:
                        traverse(child, new_path)

        elif isinstance(node, list):
            for child in node:
                traverse(child, path_titles)

    traverse(moji_tree, [])
    print(f"\n✅ 成功！累计上传和关联了 {total_uploaded} 个单词。")

if __name__ == "__main__":
    main()
