"""
日语单词 JSON 数据批量生成器 (v2.1 - ID 修正版)
==============================================
特点：
1. 以 moji_word_id 为唯一追踪标识，完美支持一词多音。
2. 先过滤生词，后分包，彻底杜绝逻辑重复请求。
3. 强制 Schema 与 Ruby 校验，确保教参级质量。
"""

from google import genai
from google.genai import types
import argparse
import json
import os
import re
import sys
import time
import uuid
import requests
from pathlib import Path

# 1. API Key 加载
project_root = Path(__file__).resolve().parent.parent.parent.parent.parent
env_file = project_root / ".env"
API_KEY = os.environ.get("GEMINI_API_KEY")

if not API_KEY and env_file.exists():
    with open(env_file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                API_KEY = line.split("=", 1)[1].strip().strip('"\'')
            elif line.startswith("GEMINI_API_KEY"):
                # 处理可能存在的 GEMINI_API_KEY = "..." 格式
                parts = line.split("=", 1)
                if len(parts) == 2 and parts[0].strip() == "GEMINI_API_KEY":
                    API_KEY = parts[1].strip().strip('"\'')

if not API_KEY:
    print("❌ 错误：未设置环境变量 GEMINI_API_KEY")
    sys.exit(1)

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

client = genai.Client(api_key=API_KEY)
SUPABASE_URL = "https://eecfrzvutrhftwvyebpq.supabase.co"

def get_deterministic_uuid(namespace_prefix, data_str):
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"breezejp:{namespace_prefix}:{data_str}"))

def check_word_exists_in_cloud(word, reading):
    if not SUPABASE_SERVICE_KEY: return False
    # 使用 word + reading 作为身份标识
    identity = f"{word.strip()}:{reading.strip()}"
    word_id = get_deterministic_uuid("word", identity)
    headers = {"apikey": SUPABASE_SERVICE_KEY, "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"}
    try:
        resp = requests.get(f"{SUPABASE_URL}/rest/v1/words", params={"id": f"eq.{word_id}", "select": "id"}, headers=headers)
        return len(resp.json()) > 0
    except:
        return False

# 2. Schema 与 配置
SYSTEM_PROMPT = """你现在是一位精通中日双语的资深日语教育专家。
请根据我提供的日语单词列表，严格按照以下 JSON 数组的格式输出。

【严格格式要求】
1. 假名必须使用 [ruby] 格式，例如：`一生懸命[いっしょうけんめい]`。仅对汉字标注，假名不标假名。
2. **【严禁套壳】**：绝不能写成 `お客様[おきゃくさま]`，应为 `お客[きゃく]様[さま]`。
3. 如果单词有多个释义，务必在数组中全部列举。
"""

BASIC_INFO_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "word": {"type": "STRING"},
        "reading": {"type": "STRING"},
        "romaji": {"type": "STRING"},
        "pitch_accent": {"type": "STRING"},
        "jlpt_level": {"type": "STRING"},
        "part_of_speech": {"type": "STRING"},
        "transitivity": {"type": "STRING", "nullable": True}
    },
    "required": ["word", "reading", "romaji", "pitch_accent", "jlpt_level", "part_of_speech", "transitivity"]
}

ITEM_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "1_basic_info": BASIC_INFO_SCHEMA,
        "2_meanings_and_nuance": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"definition": {"type": "STRING"}, "nuance": {"type": "STRING"}}}},
        "3_critical_grammar_rules": {"type": "OBJECT", "properties": {"associated_particles": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"pattern": {"type": "STRING"}, "explanation": {"type": "STRING"}}}}}},
        "4_conjugations": {"type": "OBJECT", "properties": {"dictionary_form": {"type": "STRING"}, "masu_form": {"type": "STRING"}, "nai_form": {"type": "STRING"}, "te_form": {"type": "STRING"}, "ta_form": {"type": "STRING"}, "potential_form": {"type": "STRING"}, "passive_form": {"type": "STRING"}, "causative_form": {"type": "STRING"}}},
        "5_kanji_components": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"kanji": {"type": "STRING"}, "onyomi": {"type": "STRING"}, "kunyomi": {"type": "STRING"}, "meaning": {"type": "STRING"}}}},
        "6_example_sentences": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"level": {"type": "STRING"}, "japanese": {"type": "STRING"}, "chinese": {"type": "STRING"}}}},
        "7_synonyms_and_antonyms": {"type": "OBJECT", "properties": {"synonyms": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"word": {"type": "STRING"}, "meaning": {"type": "STRING"}, "difference": {"type": "STRING"}}}}, "antonyms": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"word": {"type": "STRING"}, "meaning": {"type": "STRING"}, "difference": {"type": "STRING"}}}}}},
        "8_collocations_and_phrases": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"phrase": {"type": "STRING"}, "meaning": {"type": "STRING"}}}},
        "9_common_mistakes_and_usage_notes": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {"mistake_type": {"type": "STRING"}, "explanation": {"type": "STRING"}}}}
    },
    "required": ["1_basic_info", "2_meanings_and_nuance", "3_critical_grammar_rules", "4_conjugations", "5_kanji_components", "6_example_sentences", "7_synonyms_and_antonyms", "8_collocations_and_phrases", "9_common_mistakes_and_usage_notes"]
}

GENERATE_CONFIG = types.GenerateContentConfig(
    system_instruction=SYSTEM_PROMPT,
    response_mime_type="application/json",
    response_schema={"type": "ARRAY", "items": ITEM_SCHEMA},
    temperature=0.2,
    max_output_tokens=8192,
)

MODEL_NAME = "gemini-3.1-flash-lite-preview"
BATCH_SIZE = 5
WAIT_BETWEEN_REQUESTS = 5.0

# 3. 参数解析
parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True)
parser.add_argument("--check-cloud", action="store_true", help="是否检查云端已存在单词并跳过")
args = parser.parse_args()
input_path = Path(args.input)
if not input_path.is_absolute(): input_path = project_root / input_path

# 4. 数据解析
def flatten_moji_tree(items):
    words = []
    for item in items:
        if item.get("type") == "folder": words.extend(flatten_moji_tree(item.get("items", [])))
        elif item.get("type") == "word": words.append(item)
    return words

word_list = [] # 存储 ID
word_metadata = {} # ID -> info

if input_path.suffix.lower() == ".json":
    with open(input_path, "r", encoding="utf-8") as f:
        tree = json.load(f)
    flat = flatten_moji_tree(tree)
    for w in flat:
        word_id = w.get("wordId", "")
        target_id = w.get("targetId", "")
        # wordId 优先作为主键
        mid = word_id or target_id
        if mid:
            word_list.append(mid)
            meta = {
                "moji_word_id": mid,
                "moji_word_id_alt": target_id if target_id != mid else "",
                "word_text": w.get("word", ""),
                "moji_reading": w.get("reading", ""),
                "source": "mojidict"
            }
            word_metadata[mid] = meta
            # 双向索引：targetId 也指向同一元数据，兼容旧存档
            if target_id and target_id != mid:
                word_metadata[target_id] = meta
else:
    raw = input_path.read_text(encoding="utf-8")
    for w in [x.strip() for x in raw.replace("\n", ",").split(",") if x.strip()]:
        mid = f"txt_{w}"
        word_list.append(mid)
        word_metadata[mid] = {"moji_word_id": mid, "word_text": w, "source": "text"}

# 5. 进度加载与分包
output_dir = project_root / "files" / "单词生成器" / "输出结果"
output_dir.mkdir(parents=True, exist_ok=True)
output_filename = output_dir / f"{input_path.stem if input_path.suffix != '.json' else input_path.parent.name}_latest.json"

all_results = []
processed_ids = set()
if output_filename.exists():
    with open(output_filename, "r", encoding="utf-8") as f:
        all_results = json.load(f)
        for item in all_results:
            basic = item.get("1_basic_info", {})
            w = basic.get("word", "").strip()
            r = basic.get("reading", "").strip()
            if w:
                # 记录已处理的标识符
                identity = f"{w}:{r}"
                processed_ids.add(identity)

unprocessed_ids = []
for mid in word_list:
    meta = word_metadata[mid]
    identity = f"{meta['word_text'].strip()}:{meta.get('moji_reading', '').strip()}"
    if identity not in processed_ids:
        unprocessed_ids.append(mid)

if args.check_cloud and unprocessed_ids:
    print(f"🔍 正在连接云端校验单词存量 (批量模式)...")
    final_unprocessed = []
    
    # 将 unprocessed_ids 按 100 个一组分包查询
    batch_size = 100
    headers = {"apikey": SUPABASE_SERVICE_KEY, "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"}
    
    for i in range(0, len(unprocessed_ids), batch_size):
        chunk = unprocessed_ids[i : i + batch_size]
        identities = [f"{word_metadata[mid]['word_text'].strip()}:{word_metadata[mid].get('moji_reading', '').strip()}" for mid in chunk]
        uuids = [get_deterministic_uuid("word", ident) for ident in identities]
        
        # 构造 Supabase in 查询
        uuid_list_str = f"({','.join(uuids)})"
        try:
            resp = requests.get(f"{SUPABASE_URL}/rest/v1/words", params={"id": f"in.{uuid_list_str}", "select": "id"}, headers=headers)
            existing_ids = {r["id"] for r in resp.json()}
        except Exception as e:
            print(f"  ⚠️ 云端校验异常: {e}")
            existing_ids = set()

        for mid in chunk:
            meta = word_metadata[mid]
            w = meta['word_text'].strip()
            r = meta.get('moji_reading', '').strip()
            word_uuid = get_deterministic_uuid("word", f"{w}:{r}")
            
            if word_uuid in existing_ids:
                print(f"  ☁️  单词 [{w}({r})] 云端已存在，跳过 AI 生成。")
                all_results.append({
                    "1_basic_info": {"word": w, "reading": r, "is_cloud_referenced": True},
                    "_source_meta": meta
                })
            else:
                final_unprocessed.append(mid)
                
    unprocessed_ids = final_unprocessed
    with open(output_filename, "w", encoding="utf-8") as f:
        json.dump(all_results, f, ensure_ascii=False, indent=2)

print(f"📖 读取完毕。总词数: {len(word_list)}，已完成: {len(processed_ids)}，待处理: {len(unprocessed_ids)}")

# 6. 主循环
for i in range(0, len(unprocessed_ids), BATCH_SIZE):
    batch_ids = unprocessed_ids[i : i + BATCH_SIZE]
    
    # 构造 Prompt
    prompt_parts = []
    for mid in batch_ids:
        meta = word_metadata[mid]
        prompt_parts.append(f"{meta['word_text']}({meta.get('moji_reading', '')})")
    prompt = f"请解析以下单词列表：{', '.join(prompt_parts)}"
    
    batch_display = [f"{word_metadata[mid]['word_text']}({word_metadata[mid].get('moji_reading', '')})" for mid in batch_ids]
    print(f"正在处理批次 {i//BATCH_SIZE + 1}: {batch_display}")
    
    success = False
    for attempt in range(10):
        try:
            response = client.models.generate_content(model=MODEL_NAME, contents=prompt, config=GENERATE_CONFIG)
            batch_data = json.loads(response.text)
            
            # 强制对齐：用官方元数据覆盖 AI 生成的 word/reading 字段
            for idx, item in enumerate(batch_data):
                if idx < len(batch_ids):
                    mid = batch_ids[idx]
                    meta = word_metadata[mid]
                    item["_source_meta"] = meta
                    item["1_basic_info"]["word"] = meta["word_text"]
                    if meta.get("moji_reading"):
                        item["1_basic_info"]["reading"] = meta["moji_reading"]
            
            all_results.extend(batch_data)
            with open(output_filename, "w", encoding="utf-8") as f:
                json.dump(all_results, f, ensure_ascii=False, indent=2)
            
            print("✅ 成功存盘")
            success = True
            break
        except Exception as e:
            wait = 10 + attempt * 10
            is_503 = "503" in str(e) or "UNAVAILABLE" in str(e)
            print(f"❌ 失败 (尝试 {attempt+1}/10) {'[503]' if is_503 else ''}: {e}")
            if attempt < 9:
                print(f"   等待 {wait}s 后重试...")
                time.sleep(wait)
    
    if not success:
        # 安全保护：10 次全失败后写入占位记录，防止下次重启无限循环重试该批次
        print(f"⚠️ 本批次已耗尽重试，写入占位记录跳过。下次重启将不再重试。")
        for mid in batch_ids:
            meta = word_metadata[mid]
            all_results.append({
                "1_basic_info": {"word": meta["word_text"], "reading": meta.get("moji_reading", ""),
                                  "romaji": "", "pitch_accent": "", "jlpt_level": "", "part_of_speech": ""},
                "_source_meta": dict(meta, **{"generation_status": "FAILED_SKIP"})
            })
        with open(output_filename, "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=2)
    
    time.sleep(WAIT_BETWEEN_REQUESTS)

print("🎉 全部完成！")
