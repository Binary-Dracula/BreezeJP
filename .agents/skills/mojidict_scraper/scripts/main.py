import requests
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor

# ==========================================
# 1. 配置合集与项目名
# ==========================================
START_ID = "FoIhGqBo87"  # 目标 FID
PROJECT_NAME = "新标日初级下册"  # 输出文件夹名称
DOWNLOAD_AUDIO = True  # 是否抓取完后立即下载音频

# ==========================================
# 2. 连接与鉴权信息
# ==========================================
USERNAME = "summer.work.001@gmail.com"
PASSWORD = "haiyueshanc22302"
INSTALLATION_ID = "73f5f608-c8c8-4e74-9f35-93089cbb012b"
APP_ID = "E62VyFVLMiW7kvbtVq3p"

def get_session_token():
    print("[*] 正在使用账号自动获取 Session Token...")
    url = "https://api.mojidict.com/parse/login"
    headers = {
        "X-Parse-Application-Id": APP_ID,
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
    payload = {"username": USERNAME, "password": PASSWORD}
    try:
        resp = requests.post(url, data=json.dumps(payload), headers=headers, timeout=10)
        if resp.status_code == 200:
            return resp.json().get("sessionToken")
        else:
            print(f"❌ 登录失败: HTTP {resp.status_code}\n{resp.text}")
            exit(1)
    except Exception as e:
        print(f"❌ 登录请求报错: {e}")
        exit(1)

SESSION_TOKEN = get_session_token()

# 基于脚本位置寻找项目根目录 (向上 4 级)
BASE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..")
# 输出到 files/单词生成器/单词源/{PROJECT_NAME}/，与 japanese-vocab-generator 的输入目录统一
PROJECT_DIR = os.path.join(BASE_DIR, "files", "单词生成器", "单词源", PROJECT_NAME)
AUDIO_DIR = os.path.join(PROJECT_DIR, "audios")
JSON_PATH = os.path.join(PROJECT_DIR, "words.json")

HEADERS = {
    "Content-Type": "text/plain",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Origin": "https://www.mojidict.com",
    "Referer": "https://www.mojidict.com/"
}

URL = "https://api.mojidict.com/parse/functions/folder-fetchContentWithRelatives"

# 确保文件夹存在
os.makedirs(AUDIO_DIR, exist_ok=True)

def fetch_with_retry(payload, max_retries=3):
    for i in range(max_retries):
        try:
            resp = requests.post(URL, data=json.dumps(payload), headers=HEADERS, timeout=15)
            if resp.status_code == 200: return resp.json()
            elif resp.status_code == 503:
                time.sleep((i + 1) * 2)
            else: print(f"  [!] HTTP {resp.status_code}")
        except: time.sleep(1)
    return None

def fetch_recursive(fid, depth=0):
    page = 1
    page_size = 30
    indent = "  " * depth
    node_content = []
    
    payload = {
        "fid": fid, "count": page_size, "pageIndex": 1, "sortType": 0,
        "_SessionToken": SESSION_TOKEN, "_ClientVersion": "js4.3.1",
        "_ApplicationId": APP_ID, "g_os": "PCWeb", "g_ver": "4.15.9",
        "_InstallationId": INSTALLATION_ID
    }
    
    data_all = fetch_with_retry(payload)
    if not data_all: return []
    
    res_json = data_all.get("result", {})
    total_pages = res_json.get("totalPage", 1)

    while page <= total_pages:
        if page > 1:
            payload["pageIndex"] = page
            data_all = fetch_with_retry(payload)
            if not data_all: break
            res_json = data_all.get("result", {})
            
        page_items = res_json.get("result", [])
        if not page_items: break

        for item in page_items:
            t_type = item.get("targetType")
            t_id = item.get("targetId")
            title = item.get("title", "")

            if t_type in [1000, 2000, 5000] and t_id != fid:
                print(f"{indent}目录 -> {title}")
                sub_tree = fetch_recursive(t_id, depth + 1)
                node_content.append({"type": "folder", "title": title, "id": t_id, "items": sub_tree})
                time.sleep(0.3)
            else:
                target = item.get("target", {})
                word_id = target.get("wordId") or t_id
                audio_url = f"https://oss.mojidict.com/tts_v2/102%23{word_id}%23f002.mp3" if word_id else ""
                node_content.append({
                    "type": "word", "word": title, "reading": target.get("pron", ""),
                    "accent": target.get("accent", ""), "meaning": target.get("trans", ""),
                    "audio": audio_url, "targetId": t_id, "wordId": word_id
                })
        page += 1
        time.sleep(0.05)
    return node_content

def download_audio_file(word_info):
    url = word_info.get("audio")
    w_id = word_info.get("wordId")
    if not url or not w_id: return
    
    file_path = os.path.join(AUDIO_DIR, f"{w_id}.mp3")
    if os.path.exists(file_path): return # 断点续传
    
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            with open(file_path, "wb") as f: f.write(r.content)
    except: pass

def get_flattened_words(tree):
    words = []
    for item in tree:
        if item.get("type") == "folder":
            words.extend(get_flattened_words(item.get("items", [])))
        else: words.append(item)
    return words

import re
CHINESE_NUMS = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    '十一': 11, '十二': 12, '十三': 13, '十四': 14, '十五': 15,
    '十六': 16, '十七': 17, '十八': 18, '十九': 19, '二十': 20,
    '二十一': 21, '二十二': 22, '二十三': 23, '二十四': 24, '二十五': 25,
    '二十六': 26, '二十七': 27, '二十八': 28, '二十九': 29, '三十': 30
}

def extract_number(title):
    match = re.search(r'第([一二三四五六七八九十]+)(单元|课)', title)
    if match:
        num_str = match.group(1)
        return CHINESE_NUMS.get(num_str, 999)
    return 999

def sort_tree(items):
    for item in items:
        if item.get("type") == "folder" and "items" in item:
            sort_tree(item["items"])
    if all(i.get("type") == "folder" for i in items):
        items.sort(key=lambda x: extract_number(x.get("title", "")))

def run_spider():
    print(f"[*] 项目启动: {PROJECT_NAME}")
    print(f"[*] 存储根目录: {PROJECT_DIR}")
    
    # 1. 抓取 JSON
    tree = fetch_recursive(START_ID)
    
    # 对树进行基于课、单元序号的排序
    sort_tree(tree)
    
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(tree, f, ensure_ascii=False, indent=2)
    print(f"[√] 单词数据抓取完成: {JSON_PATH}")

    # 2. 下载音频
    if DOWNLOAD_AUDIO:
        all_words = get_flattened_words(tree)
        print(f"[*] 准备下载 {len(all_words)} 个音频文件...")
        with ThreadPoolExecutor(max_workers=15) as executor:
            executor.map(download_audio_file, all_words)
        print(f"[√] 音频下载完成")

if __name__ == "__main__":
    run_spider()
