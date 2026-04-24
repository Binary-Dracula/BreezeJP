#!/usr/bin/env python3
"""
MOJi 辞书数据抓取脚本 (v3.0)
============================
从 MOJiDict 抓取完整单词合集（树形结构 + 音频），
输出到 data/vocab/sources/{book_name}/。

用法:
  python scrape.py                                          # 交互模式
  python scrape.py --book-name "新标日初级上册" --collection-id "FoIhGqBo87"

特性:
  - 指数退避重试 (HTTP 错误)
  - 音频下载带重试 + 校验
  - 断点续传 (已下载音频自动跳过)
  - 课序自动排序
"""

import argparse
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# 将 _vocab_common 加入 import 路径
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from _vocab_common import config
from _vocab_common.constants import MOJI_APP_ID, MOJI_API_BASE, MOJI_INSTALLATION_ID, SOURCES_DIR
from _vocab_common.retry import retry_call

import requests


# ============================================================
# MOJi API 交互
# ============================================================

FETCH_URL = f"{MOJI_API_BASE}/parse/functions/folder-fetchContentWithRelatives"

HEADERS = {
    "Content-Type": "text/plain",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    "Accept": "application/json, text/plain, */*",
    "Origin": "https://www.mojidict.com",
    "Referer": "https://www.mojidict.com/",
}


def get_session_token(username: str, password: str) -> str:
    """使用账号密码自动获取 Session Token。"""
    url = f"{MOJI_API_BASE}/parse/login"
    headers = {
        "X-Parse-Application-Id": MOJI_APP_ID,
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
    }
    payload = {"username": username, "password": password}

    def _login():
        resp = requests.post(url, json=payload, headers=headers, timeout=15)
        if resp.status_code == 200:
            token = resp.json().get("sessionToken")
            if token:
                return token
            raise RuntimeError("响应中未包含 sessionToken")
        raise RuntimeError(f"登录失败: HTTP {resp.status_code} - {resp.text[:200]}")

    return retry_call(_login, max_retries=3, base_delay=3.0, max_delay=15.0)


def fetch_page(fid: str, page: int, session_token: str) -> dict:
    """获取一个文件夹的单页内容。"""
    payload = {
        "fid": fid, "count": 30, "pageIndex": page, "sortType": 0,
        "_SessionToken": session_token, "_ClientVersion": "js4.3.1",
        "_ApplicationId": MOJI_APP_ID, "g_os": "PCWeb", "g_ver": "4.15.9",
        "_InstallationId": MOJI_INSTALLATION_ID,
    }

    def _fetch():
        resp = requests.post(FETCH_URL, data=json.dumps(payload), headers=HEADERS, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        raise RuntimeError(f"HTTP {resp.status_code}")

    return retry_call(_fetch, max_retries=5, base_delay=2.0, max_delay=30.0)


def fetch_recursive(fid: str, session_token: str, depth: int = 0) -> list:
    """递归抓取文件夹树形结构。"""
    indent = "  " * depth
    node_content = []

    first_page = fetch_page(fid, 1, session_token)
    if not first_page:
        return []

    res_json = first_page.get("result", {})
    total_pages = res_json.get("totalPage", 1)
    page = 1

    while page <= total_pages:
        if page > 1:
            page_data = fetch_page(fid, page, session_token)
            if not page_data:
                break
            res_json = page_data.get("result", {})

        page_items = res_json.get("result", [])
        if not page_items:
            break

        for item in page_items:
            t_type = item.get("targetType")
            t_id = item.get("targetId")
            title = item.get("title", "")

            if t_type in (1000, 2000, 5000) and t_id != fid:
                print(f"{indent}📂 目录: {title}")
                sub_tree = fetch_recursive(t_id, session_token, depth + 1)
                node_content.append({
                    "type": "folder", "title": title, "id": t_id,
                    "items": sub_tree,
                })
                time.sleep(0.3)
            else:
                target = item.get("target", {})
                word_id = target.get("wordId") or t_id
                audio_url = (
                    f"https://oss.mojidict.com/tts_v2/102%23{word_id}%23f002.mp3"
                    if word_id else ""
                )
                node_content.append({
                    "type": "word",
                    "word": title,
                    "reading": target.get("pron", ""),
                    "accent": target.get("accent", ""),
                    "meaning": target.get("trans", ""),
                    "audio": audio_url,
                    "targetId": t_id,
                    "wordId": word_id,
                })

        page += 1
        time.sleep(0.05)

    return node_content


# ============================================================
# 排序
# ============================================================

CHINESE_NUMS = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    '十一': 11, '十二': 12, '十三': 13, '十四': 14, '十五': 15,
    '十六': 16, '十七': 17, '十八': 18, '十九': 19, '二十': 20,
    '二十一': 21, '二十二': 22, '二十三': 23, '二十四': 24, '二十五': 25,
    '二十六': 26, '二十七': 27, '二十八': 28, '二十九': 29, '三十': 30,
}


def extract_number(title: str) -> int:
    match = re.search(r'第([一二三四五六七八九十]+)(单元|课)', title)
    if match:
        return CHINESE_NUMS.get(match.group(1), 999)
    return 999


def sort_tree(items: list):
    """递归排序文件夹（按课号/单元号）。"""
    for item in items:
        if item.get("type") == "folder" and "items" in item:
            sort_tree(item["items"])
    if all(i.get("type") == "folder" for i in items):
        items.sort(key=lambda x: extract_number(x.get("title", "")))


# ============================================================
# 音频下载
# ============================================================

def flatten_words(tree: list) -> list:
    words = []
    for item in tree:
        if item.get("type") == "folder":
            words.extend(flatten_words(item.get("items", [])))
        elif item.get("type") == "word":
            words.append(item)
    return words


def download_audio(word_info: dict, audio_dir: Path):
    """下载单个音频文件，带重试和大小校验。"""
    url = word_info.get("audio")
    w_id = word_info.get("wordId")
    if not url or not w_id:
        return

    file_path = audio_dir / f"{w_id}.mp3"
    if file_path.exists() and file_path.stat().st_size > 0:
        return  # 断点续传：已存在且非空则跳过

    def _download():
        r = requests.get(url, timeout=15)
        if r.status_code == 200:
            if len(r.content) < 100:
                raise RuntimeError(f"音频文件过小 ({len(r.content)} bytes)，可能无效")
            with open(file_path, "wb") as f:
                f.write(r.content)
            return
        raise RuntimeError(f"HTTP {r.status_code}")

    try:
        retry_call(_download, max_retries=3, base_delay=1.0, max_delay=10.0)
    except Exception as e:
        print(f"  ⚠️ 音频下载失败: {word_info.get('word', w_id)} - {e}")


# ============================================================
# 主入口
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="MOJi 辞书数据抓取")
    parser.add_argument("--book-name", help="辞书名/项目名 (用作目录名)")
    parser.add_argument("--collection-id", help="MOJi 合集 FID")
    args = parser.parse_args()

    # 交互输入
    book_name = args.book_name
    if not book_name:
        book_name = input("📖 请输入辞书名 (如: 新标日初级上册): ").strip()

    collection_id = args.collection_id
    if not collection_id:
        collection_id = input("🔑 请输入 MOJi 合集 ID (如: FoIhGqBo87): ").strip()

    if not book_name or not collection_id:
        print("❌ 辞书名和合集 ID 不能为空")
        sys.exit(1)

    # 路径
    project_root = config.PROJECT_ROOT
    sources_dir = project_root / SOURCES_DIR / book_name
    audio_dir = sources_dir / "audios"
    json_path = sources_dir / "words.json"
    audio_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"  辞书名:    {book_name}")
    print(f"  合集 ID:   {collection_id}")
    print(f"  输出目录:  {sources_dir}")
    print(f"{'='*60}\n")

    # 1. 获取 Session Token
    print("[1/3] 正在登录 MOJi...")
    username = config.moji_username()
    password = config.moji_password()
    session_token = get_session_token(username, password)
    print("  ✅ 登录成功\n")

    # 2. 递归抓取数据
    print("[2/3] 正在抓取词库数据...")
    tree = fetch_recursive(collection_id, session_token)
    sort_tree(tree)

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(tree, f, ensure_ascii=False, indent=2)

    all_words = flatten_words(tree)
    print(f"  ✅ 数据抓取完成: {len(all_words)} 个单词\n")

    # 3. 下载音频
    print(f"[3/3] 正在下载音频 ({len(all_words)} 个)...")
    completed = 0
    failed = 0

    def download_one(word):
        nonlocal completed, failed
        try:
            download_audio(word, audio_dir)
            completed += 1
        except Exception:
            failed += 1

    with ThreadPoolExecutor(max_workers=15) as executor:
        futures = [executor.submit(download_one, w) for w in all_words]
        for future in as_completed(futures):
            future.result()  # 触发异常打印
            done = completed + failed
            if done % 50 == 0 or done == len(all_words):
                print(f"  进度: {done}/{len(all_words)}")

    # 统计缺失音频
    missing = sum(1 for w in all_words
                  if w.get("wordId") and not (audio_dir / f"{w['wordId']}.mp3").exists())

    print(f"\n{'='*60}")
    print(f"  ✅ 抓取完成!")
    print(f"  单词总数:   {len(all_words)}")
    print(f"  音频下载:   {completed - missing} 成功")
    if missing:
        print(f"  缺失音频:   {missing} (可稍后用 --book-name 重新运行补抓)")
    print(f"  输出文件:   {json_path}")
    print(f"  音频目录:   {audio_dir}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
