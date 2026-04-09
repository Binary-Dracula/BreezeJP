import os
import json
import requests
from concurrent.futures import ThreadPoolExecutor

# --- 配置 (请确保 PROJECT_NAME 与 main.py 一致) ---
PROJECT_NAME = "nsh_junior_upper" 
# 基于脚本位置寻找项目根目录 (向上 4 级)
BASE_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..")
# 与 main.py 统一，输出到 files/单词生成器/单词源/{PROJECT_NAME}/
PROJECT_DIR = os.path.join(BASE_DIR, "files", "单词生成器", "单词源", PROJECT_NAME)
JSON_FILE = os.path.join(PROJECT_DIR, "words.json")
AUDIO_DIR = os.path.join(PROJECT_DIR, "audios")

os.makedirs(AUDIO_DIR, exist_ok=True)

def get_flattened_words(items):
    words = []
    for it in items:
        if it.get("type") == "folder":
            words.extend(get_flattened_words(it.get("items", [])))
        else: words.append(it)
    return words

def download_audio(word_info):
    url = word_info.get("audio")
    w_id = word_info.get("wordId")
    if not url or not w_id: return

    file_path = os.path.join(AUDIO_DIR, f"{w_id}.mp3")
    if os.path.exists(file_path): return
    
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            with open(file_path, "wb") as f: f.write(r.content)
            print(f"  [+] 下载成功: {word_info.get('word')} ({w_id}.mp3)")
        else:
            print(f"  [X] HTTP {r.status_code}: {word_info.get('word')}")
    except Exception as e:
        print(f"  [!] 出错: {word_info.get('word')} - {e}")

# 执行逻辑
if __name__ == "__main__":
    if not os.path.exists(JSON_FILE):
        print(f"找不到 {JSON_FILE}，请先运行 main.py 抓取数据。")
    else:
        with open(JSON_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        all_words = get_flattened_words(data)
        print(f"[*] 开始补抓 {len(all_words)} 个音频文件到 {AUDIO_DIR}...")
        with ThreadPoolExecutor(max_workers=20) as executor:
            executor.map(download_audio, all_words)
        print("\n[*] 音频补音任务完成！")
