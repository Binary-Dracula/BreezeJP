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

CIRCLED_DIGITS = {
    "⓪": "0",
    "①": "1",
    "②": "2",
    "③": "3",
    "④": "4",
    "⑤": "5",
    "⑥": "6",
    "⑦": "7",
    "⑧": "8",
    "⑨": "9",
    "⑩": "10",
}
NULL_STRINGS = {"null", "none", "nil"}
CONJUGATION_KEYS = (
    "dictionary_form",
    "masu_form",
    "nai_form",
    "te_form",
    "ta_form",
    "potential_form",
    "passive_form",
    "causative_form",
)
POS_TOKEN_MAP = {
    "名詞": "名词",
    "動詞": "动词",
    "自動詞": "自动词",
    "他動詞": "他动词",
    "副詞": "副词",
    "形容詞": "形容词",
    "形容動詞": "形容动词",
    "代名詞": "代词",
    "接尾語": "接尾词",
    "接尾詞": "接尾词",
    "連体詞": "连体词",
    "接続詞": "接续词",
    "感動詞": "感叹词",
    "固有名詞": "专有名词",
    "数量詞": "量词",
    "サ変動詞": "サ变动词",
    "サ変名詞": "サ变名词",
    "ナ形容詞": "な形容词",
    "イ形容詞": "い形容词",
    "五段動詞": "五段动词",
    "一段動詞": "一段动词",
}
POS_SUBSTRING_MAP = {
    "na形容词": "な形容词",
    "形容詞": "形容词",
    "形容動詞": "形容动词",
    "する動詞": "サ变动词",
    "接尾辞": "接尾词",
    "慣用句": "惯用句",
    "副助詞": "副助词",
    "助詞": "助词",
    "な形容詞": "な形容词",
    "名詞・": "名词/",
    "他サ": "他动词/サ变动词",
    "自サ": "自动词/サ变动词",
}
POS_EXACT_MAP = {
    "i形容词": "い形容词",
    "na形容词": "な形容词",
    "名词,他动词": "名词/他动词",
    "名词,自动词": "名词/自动词",
    "名词,副词": "名词/副词",
    "名词,形容动词": "名词/形容动词",
    "名词,サ变动词": "名词/サ变动词",
    "名詞,他動詞": "名词/他动词",
    "名詞,自動詞": "名词/自动词",
}

def get_deterministic_uuid(namespace_prefix, data_str):
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"breezejp:{namespace_prefix}:{data_str}"))

def clean_text(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value)

def has_japanese_characters(text):
    text = clean_text(text)
    if not text:
        return False
    for ch in text:
        code = ord(ch)
        if (0x3040 <= code <= 0x309F) or (0x30A0 <= code <= 0x30FF) or (0x4E00 <= code <= 0x9FFF):
            return True
    return False

def normalize_nullish(value):
    if isinstance(value, dict):
        return {k: normalize_nullish(v) for k, v in value.items()}
    if isinstance(value, list):
        return [normalize_nullish(v) for v in value]
    if isinstance(value, str) and value.strip().lower() in NULL_STRINGS:
        return None
    return value

def hiragana_to_katakana(text):
    chars = []
    for ch in text:
        code = ord(ch)
        if 0x3041 <= code <= 0x3096:
            chars.append(chr(code + 0x60))
        else:
            chars.append(ch)
    return "".join(chars)

def normalize_reading(word_text, reading_text):
    reading = clean_text(reading_text)
    if not reading:
        return ""
    if re.fullmatch(r"[A-Z0-9][A-Z0-9&+\-]*", clean_text(word_text)):
        reading = re.sub(r"\s+", "", reading)
        reading = hiragana_to_katakana(reading)
    return reading

def normalize_jlpt_level(value):
    jlpt = clean_text(value).upper()
    if not jlpt:
        return ""
    return "N/A" if jlpt in {"N/A", "NA"} else jlpt

def normalize_part_of_speech(value):
    pos = clean_text(value)
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
    normalized_parts = [POS_TOKEN_MAP.get(part, part) for part in parts]
    return "/".join(normalized_parts)

def normalize_pitch_accent(value):
    if value is None:
        return None
    text = clean_text(value)
    if not text:
        return None
    lowered = text.lower()
    if lowered in NULL_STRINGS or text in {"无固定", "無固定", "不定"}:
        return None
    circled_numbers = [CIRCLED_DIGITS[ch] for ch in text if ch in CIRCLED_DIGITS]
    if circled_numbers:
        return "/".join(circled_numbers)
    compact = re.sub(r"\s+", "", text)
    if "平板" in compact and not re.search(r"\d", compact):
        return "0"
    numbers = re.findall(r"\d+", compact)
    if numbers:
        deduped = []
        for number in numbers:
            if not deduped or deduped[-1] != number:
                deduped.append(number)
        return "/".join(deduped)
    return compact

def normalize_transitivity(value):
    normalized = normalize_part_of_speech(value)
    if normalized in {"自动词", "他动词"}:
        return normalized
    return None if not normalized else normalized

def make_source_meta(raw_meta=None, fallback_word="", fallback_reading=""):
    raw_meta = normalize_nullish(dict(raw_meta or {}))
    moji_word_id = clean_text(raw_meta.get("moji_word_id"))
    moji_target_id = clean_text(raw_meta.get("moji_target_id") or raw_meta.get("moji_word_id_alt"))
    if not moji_target_id:
        moji_target_id = moji_word_id
    meta = {
        "moji_word_id": moji_word_id,
        "moji_target_id": moji_target_id,
        "moji_word_id_alt": "" if moji_target_id == moji_word_id else moji_target_id,
        "word_text": clean_text(raw_meta.get("word_text") or fallback_word),
        "moji_reading": clean_text(raw_meta.get("moji_reading") or fallback_reading),
        "moji_accent": normalize_pitch_accent(raw_meta.get("moji_accent")),
        "moji_meaning": clean_text(raw_meta.get("moji_meaning")),
        "source": clean_text(raw_meta.get("source") or "mojidict"),
    }
    return meta

def merge_source_meta(authoritative_meta, existing_meta, fallback_word="", fallback_reading=""):
    merged = make_source_meta(authoritative_meta, fallback_word=fallback_word, fallback_reading=fallback_reading)
    extra = make_source_meta(existing_meta, fallback_word=fallback_word, fallback_reading=fallback_reading)
    for key, value in extra.items():
        if merged.get(key) in {"", None} and value not in {"", None}:
            merged[key] = value
    if not merged.get("moji_target_id") and merged.get("moji_word_id"):
        merged["moji_target_id"] = merged["moji_word_id"]
    if merged.get("moji_target_id") == merged.get("moji_word_id"):
        merged["moji_word_id_alt"] = ""
    return merged

def normalize_output_item(item, authoritative_meta=None):
    item = normalize_nullish(item or {})
    basic = dict(item.get("1_basic_info") or {})
    meta = merge_source_meta(authoritative_meta, item.get("_source_meta"), fallback_word=basic.get("word", ""), fallback_reading=basic.get("reading", ""))

    word_text = meta.get("word_text") or clean_text(basic.get("word"))
    reading_text = meta.get("moji_reading") or clean_text(basic.get("reading"))
    pitch_source = meta.get("moji_accent")

    normalized_item = {
        "1_basic_info": {
            "word": word_text,
            "reading": normalize_reading(word_text, reading_text),
            "romaji": clean_text(basic.get("romaji")),
            "pitch_accent": normalize_pitch_accent(pitch_source if pitch_source is not None else basic.get("pitch_accent")),
            "jlpt_level": normalize_jlpt_level(basic.get("jlpt_level")),
            "part_of_speech": normalize_part_of_speech(basic.get("part_of_speech")),
            "transitivity": normalize_transitivity(basic.get("transitivity")),
        },
        "2_meanings_and_nuance": item.get("2_meanings_and_nuance") or [],
        "3_critical_grammar_rules": item.get("3_critical_grammar_rules") or {"associated_particles": []},
        "4_conjugations": {},
        "5_kanji_components": item.get("5_kanji_components") or [],
        "6_example_sentences": item.get("6_example_sentences") or [],
        "7_synonyms_and_antonyms": item.get("7_synonyms_and_antonyms") or {"synonyms": [], "antonyms": []},
        "8_collocations_and_phrases": item.get("8_collocations_and_phrases") or [],
        "9_common_mistakes_and_usage_notes": item.get("9_common_mistakes_and_usage_notes") or [],
        "_source_meta": meta,
    }

    grammar_rules = normalized_item["3_critical_grammar_rules"]
    if not isinstance(grammar_rules, dict):
        grammar_rules = {"associated_particles": []}
    grammar_rules["associated_particles"] = grammar_rules.get("associated_particles") or []
    normalized_item["3_critical_grammar_rules"] = grammar_rules

    synonyms_antonyms = normalized_item["7_synonyms_and_antonyms"]
    if not isinstance(synonyms_antonyms, dict):
        synonyms_antonyms = {"synonyms": [], "antonyms": []}
    synonyms_antonyms["synonyms"] = synonyms_antonyms.get("synonyms") or []
    synonyms_antonyms["antonyms"] = synonyms_antonyms.get("antonyms") or []
    normalized_item["7_synonyms_and_antonyms"] = synonyms_antonyms

    conjugations = item.get("4_conjugations") or {}
    if not isinstance(conjugations, dict):
        conjugations = {}
    for key in CONJUGATION_KEYS:
        value = conjugations.get(key)
        normalized_item["4_conjugations"][key] = clean_text(value) if isinstance(value, str) and clean_text(value) else None if value is None else value
        if isinstance(normalized_item["4_conjugations"][key], str) and normalized_item["4_conjugations"][key].lower() in NULL_STRINGS:
            normalized_item["4_conjugations"][key] = None

    return normalized_item

def score_output_item(item):
    basic = item.get("1_basic_info", {})
    meta = item.get("_source_meta", {})
    score = 0
    if basic.get("word"):
        score += 10
    if basic.get("reading"):
        score += 8
    if basic.get("part_of_speech"):
        score += 3
    if basic.get("pitch_accent") not in {None, ""}:
        score += 2
    score += len(item.get("2_meanings_and_nuance") or []) * 3
    score += len(item.get("6_example_sentences") or [])
    if meta.get("generation_status") == "FAILED_SKIP":
        score -= 100
    return score

def normalize_existing_results(results, source_meta_by_id, source_order):
    ordered = []
    deduped = {}
    changed = False
    allowed_source_ids = set(source_order)

    for raw_item in results:
        raw_meta = raw_item.get("_source_meta", {}) if isinstance(raw_item, dict) else {}
        mid = clean_text(raw_meta.get("moji_word_id"))
        if mid and mid not in allowed_source_ids:
            changed = True
            continue
        authoritative_meta = source_meta_by_id.get(mid, {}) if mid else {}
        normalized_item = normalize_output_item(raw_item, authoritative_meta)
        key = clean_text(normalized_item.get("_source_meta", {}).get("moji_word_id"))
        if not key:
            basic = normalized_item.get("1_basic_info", {})
            key = f"{clean_text(basic.get('word'))}:{clean_text(basic.get('reading'))}"

        if key not in deduped:
            ordered.append(key)
            deduped[key] = normalized_item
            if normalized_item != raw_item:
                changed = True
            continue

        changed = True
        if score_output_item(normalized_item) > score_output_item(deduped[key]):
            deduped[key] = normalized_item

    source_order_index = {mid: idx for idx, mid in enumerate(source_order)}
    normalized_results = [deduped[key] for key in ordered]
    normalized_results.sort(key=lambda item: source_order_index.get(clean_text(item.get("_source_meta", {}).get("moji_word_id")), len(source_order_index)))
    return normalized_results, changed

def build_placeholder_item(meta, status):
    item = normalize_output_item({
        "1_basic_info": {
            "word": meta.get("word_text", ""),
            "reading": meta.get("moji_reading", ""),
            "romaji": "",
            "pitch_accent": None,
            "jlpt_level": "",
            "part_of_speech": "",
            "transitivity": None,
        },
        "2_meanings_and_nuance": [],
        "3_critical_grammar_rules": {"associated_particles": []},
        "4_conjugations": {key: None for key in CONJUGATION_KEYS},
        "5_kanji_components": [],
        "6_example_sentences": [],
        "7_synonyms_and_antonyms": {"synonyms": [], "antonyms": []},
        "8_collocations_and_phrases": [],
        "9_common_mistakes_and_usage_notes": [],
        "_source_meta": dict(meta, **{"generation_status": status}),
    }, meta)
    item["_source_meta"]["generation_status"] = status
    return item

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
        "pitch_accent": {"type": "STRING", "nullable": True},
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
        "4_conjugations": {"type": "OBJECT", "properties": {"dictionary_form": {"type": "STRING", "nullable": True}, "masu_form": {"type": "STRING", "nullable": True}, "nai_form": {"type": "STRING", "nullable": True}, "te_form": {"type": "STRING", "nullable": True}, "ta_form": {"type": "STRING", "nullable": True}, "potential_form": {"type": "STRING", "nullable": True}, "passive_form": {"type": "STRING", "nullable": True}, "causative_form": {"type": "STRING", "nullable": True}}},
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
parser.add_argument("--check-cloud", action="store_true", help="兼容旧参数：云端查重已默认开启")
parser.add_argument("--skip-cloud-check", action="store_true", help="关闭云端查重，强制全部走 AI 生成")
args = parser.parse_args()
cloud_check_enabled = not args.skip_cloud_check
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
seen_word_ids = set()

if input_path.suffix.lower() == ".json":
    with open(input_path, "r", encoding="utf-8") as f:
        tree = json.load(f)
    flat = flatten_moji_tree(tree)
    for w in flat:
        word_text = w.get("word", "")
        if not has_japanese_characters(word_text):
            continue
        word_id = w.get("wordId", "")
        target_id = w.get("targetId", "")
        # wordId 优先作为主键
        mid = word_id or target_id
        if mid:
            meta = make_source_meta({
                "moji_word_id": mid,
                "moji_target_id": target_id,
                "moji_word_id_alt": target_id if target_id != mid else "",
                "word_text": w.get("word", ""),
                "moji_reading": w.get("reading", ""),
                "moji_accent": w.get("accent", ""),
                "moji_meaning": w.get("meaning", ""),
                "source": "mojidict",
            })
            if mid not in seen_word_ids:
                word_list.append(mid)
                seen_word_ids.add(mid)
            word_metadata[mid] = merge_source_meta(meta, word_metadata.get(mid, {}), fallback_word=w.get("word", ""), fallback_reading=w.get("reading", ""))
            # 双向索引：targetId 也指向同一元数据，兼容旧存档
            if target_id and target_id != mid:
                word_metadata[target_id] = word_metadata[mid]
else:
    raw = input_path.read_text(encoding="utf-8")
    for w in [x.strip() for x in raw.replace("\n", ",").split(",") if x.strip()]:
        mid = f"txt_{w}"
        if mid in seen_word_ids:
            continue
        seen_word_ids.add(mid)
        word_list.append(mid)
        word_metadata[mid] = make_source_meta({"moji_word_id": mid, "word_text": w, "source": "text"})

# 5. 进度加载与分包
output_dir = project_root / "files" / "单词生成器" / "输出结果"
output_dir.mkdir(parents=True, exist_ok=True)
output_filename = output_dir / f"{input_path.stem if input_path.suffix != '.json' else input_path.parent.name}_latest.json"

all_results = []
processed_ids = set()
if output_filename.exists():
    with open(output_filename, "r", encoding="utf-8") as f:
        all_results = json.load(f)
    all_results, normalized_existing = normalize_existing_results(all_results, word_metadata, word_list)
    if normalized_existing:
        with open(output_filename, "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=2)
    for item in all_results:
        meta = item.get("_source_meta", {})
        mid = clean_text(meta.get("moji_word_id"))
        if mid:
            processed_ids.add(mid)
        else:
            basic = item.get("1_basic_info", {})
            identity = f"{clean_text(basic.get('word'))}:{clean_text(basic.get('reading'))}"
            if identity != ":":
                processed_ids.add(identity)

unprocessed_ids = []
for mid in word_list:
    if mid not in processed_ids:
        unprocessed_ids.append(mid)

if cloud_check_enabled and unprocessed_ids:
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
                all_results.append(build_placeholder_item(meta, "CLOUD_REFERENCE"))
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
                    batch_data[idx] = normalize_output_item(item, meta)
            
            all_results.extend(batch_data)
            all_results, _ = normalize_existing_results(all_results, word_metadata, word_list)
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
            all_results.append(build_placeholder_item(meta, "FAILED_SKIP"))
        all_results, _ = normalize_existing_results(all_results, word_metadata, word_list)
        with open(output_filename, "w", encoding="utf-8") as f:
            json.dump(all_results, f, ensure_ascii=False, indent=2)
    
    time.sleep(WAIT_BETWEEN_REQUESTS)

print("🎉 全部完成！")
