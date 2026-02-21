import os
import json
import re
import subprocess
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import time

# --- 配置 ---
# NHK Easy News 新域名
BASE_URL = "https://news.web.nhk/news/easy/"
NEWS_LIST_URL = f"{BASE_URL}news-list.json"

# 授权 Token (从浏览器抓取，有时效性)
# 如果失效，需要重新从浏览器获取 z_at cookie
Z_AT_TOKEN = "eyJhbGciOiJFUzI1NiIsInR5cCI6ImF0K2p3dCIsImtpZCI6ImtpZC1hdXRoei1hYzEtcHJkLTAxIn0.eyJzdWIiOiJlNzM1NmYxZS0xYTFjLTQ2MmMtOTBlMy00M2I0NmEwOGQ2MDUiLCJpc3MiOiJodHRwczovL2EuYXV0aHouYWMxLm5oayIsImFjdGl2YXRlZEJ5Ijoic2VsZi1hY3RpdmF0ZWQiLCJjbGllbnRfaWQiOiIyOTM3ODU4NDExOCIsImxpY2Vuc2VUeXBlIjoiMCIsInByb2ZpbGVUeXBlIjoiYWJyb2FkIiwiZ3JhbnRfdHlwZSI6ImF1dGhvcml6YXRpb25fY29kZSIsInByb2ZpbGVJZCI6ImU3MzU2ZjFlLTFhMWMtNDYyYy05MGUzLTQzYjQ2YTA4ZDYwNSIsInNjb3BlIjoiZ2V0Om5ld3MgZ2V0OnR2IiwiZXhwIjoxNzcxNzA1MjkwLCJpYXQiOjE3NzE2NzY0OTAsImVudGl0eSI6Im5vbmUiLCJqdGkiOiIwblBfdWFTVTRVd0lBT3pwNFh4NEJoYWtfWHVRcXVobkxyT2ZsMDExai1rIn0.Xg5SAM1znpfri_g8wvFsaOL_RzRxNKHu2wIDuP_cVM7hX2zQNNVKWwNowvmB_t-Tf1sogj_vhHyjv7NlnB9rhA"

# 文件保存目录
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")

# HTTP 请求头，必须包含 Referer 和 Cookie (z_at)
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://news.web.nhk/news/easy/",
    "Cookie": f"z_at={Z_AT_TOKEN}"
}


def check_ffmpeg():
    """检查 ffmpeg 是否已安装"""
    try:
        subprocess.run(["ffmpeg", "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        print("✅ 检测到 ffmpeg 已安装。")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ 未检测到 ffmpeg，请确保环境已安装。")
        # 由于之前已经尝试过 brew install，这里仅做警告
        pass


def get_news_list():
    """获取目前可用的 Easy News 列表"""
    try:
        print(f"📡 正在请求新闻列表: {NEWS_LIST_URL}")
        response = requests.get(NEWS_LIST_URL, headers=HEADERS)
        
        if response.status_code == 401:
            print("❌ 授权失败 (401)。请检查 Z_AT_TOKEN 是否过期。")
            return []
            
        response.raise_for_status()
        content = response.text.strip("\ufeff")
        data = json.loads(content)
        
        all_news = []
        for date_key, news_array in data[0].items():
            if date_key == "old_news":
                continue
            all_news.extend(news_array)
            
        print(f"📄 成功获取到 {len(all_news)} 篇可用新闻列表。")
        return all_news
    except Exception as e:
        print(f"❌ 获取新闻列表失败: {e}")
        return []


def parse_furigana(element):
    """将 <ruby> 标签转换为 '漢字[かんじ]' 格式"""
    if not element: return ""
    text = ""
    for child in element.children:
        if isinstance(child, str):
            text += child
        elif child.name == "ruby":
            kanji = ""
            hiragana = ""
            for sub in child.children:
                if isinstance(sub, str):
                    kanji += sub
                elif sub.name == "rt":
                    hiragana += sub.get_text()
                elif sub.name == "rb":
                    kanji += sub.get_text()
            
            kanji = kanji.strip()
            hiragana = hiragana.strip()
            
            if kanji and hiragana:
                text += f"{kanji}[{hiragana}]"
            elif kanji:
                text += kanji
        else:
            text += parse_furigana(child)
            
    return re.sub(r'\s+', ' ', text).strip()


def download_audio(news_id, voice_uri, output_path):
    """下载音频文件"""
    if not voice_uri:
        return False
        
    if os.path.exists(output_path):
        print(f"  ⏭️ 音频已存在。")
        return True

    # 优先尝试直接下载 m4a
    audio_url = f"{BASE_URL}{news_id}/{voice_uri}"
    print(f"  🔽 尝试下载音频文件: {audio_url}")
    
    try:
        r = requests.get(audio_url, headers=HEADERS, stream=True)
        if r.status_code == 200:
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
            print(f"  ✅ 音频下载完成 (m4a)。")
            return True
        else:
            print(f"  ⚠️ 直接下载失败 (HTTP {r.status_code})。尝试使用 ffmpeg 处理 m3u8...")
    except Exception as e:
        print(f"  ⚠️ 下载异常: {e}")

    # 备选：使用 ffmpeg 抓取 m3u8
    # 这里的 m3u8 地址可能需要重新根据新架构探索，先保持逻辑
    m3u8_url = f"https://media.vd.st.nhk/r/vod/news/easy_audio/{news_id}/index.m3u8"
    cmd = [
        "ffmpeg", "-y", "-i", m3u8_url, "-c:a", "libmp3lame", "-b:a", "128k",
        "-hide_banner", "-loglevel", "error", output_path.replace(".m4a", ".mp3")
    ]
    try:
        subprocess.run(cmd, check=True)
        print(f"  ✅ 音频转换完成 (mp3)。")
        return True
    except:
        print(f"  ❌ 音频下载彻底失败。")
        return False


def process_article(news_item):
    """处理单篇新闻"""
    news_id = news_item.get("news_id")
    if not news_id: return

    article_dir = os.path.join(OUTPUT_DIR, news_id)
    os.makedirs(article_dir, exist_ok=True)
    
    json_path = os.path.join(article_dir, "article.json")
    audio_path = os.path.join(article_dir, f"{news_id}.m4a")

    print(f"🔄 处理新闻: {news_item.get('title')} ({news_id})")

    # 获取 HTML
    article_url = f"{BASE_URL}{news_id}/{news_id}.html"
    try:
        response = requests.get(article_url, headers=HEADERS)
        if response.status_code != 200:
            print(f"  ❌ 文章无法访问 (HTTP {response.status_code})。")
            return
        
        response.encoding = 'utf-8'
        soup = BeautifulSoup(response.text, "html.parser")
    except Exception as e:
        print(f"  ❌ 获取文章失败: {e}")
        return

    # 解析
    title_element = soup.select_one("h1.article-main__title")
    title_furigana = parse_furigana(title_element) or news_item.get("title")

    body_element = soup.select_one("#js-article-body")
    paragraphs = []
    if body_element:
        for p in body_element.find_all("p"):
            text = parse_furigana(p)
            if text.strip(): paragraphs.append(text)
    
    article_data = {
        "news_id": news_id,
        "title": title_furigana,
        "news_time": news_item.get("news_time"),
        "paragraphs": paragraphs
    }

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(article_data, f, ensure_ascii=False, indent=2)
    print(f"  ✅ 文本解析完成。")

    # 音频
    voice_uri = news_item.get("news_easy_voice_uri")
    if voice_uri:
        download_audio(news_id, voice_uri, audio_path)
    else:
        print(f"  ℹ️ 无音频。")


def main():
    print("🚀 NHK News Web Easy 爬虫 (新版架构)")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    check_ffmpeg()
    
    news_list = get_news_list()
    if not news_list:
        # 如果获取列表失败，可能由于 Token 问题。此处可以使用硬编码的 5 条进行测试。
        print("⚠️ 无法获取列表，使用测试数据运行...")
        news_list = [
            {"news_id": "ne2026022011579", "title": "高市総理大臣...", "news_time": "2026-02-20", "news_easy_voice_uri": "ne2026022011579_EIqPYPjRzbruIPe6yXQ4WDDIpeQQjt8C7C4SsMM2.m4a"},
            {"news_id": "ne2026022011598", "title": "フィギュアスケート...", "news_time": "2026-02-20", "news_easy_voice_uri": "ne2026022011598_d6d8d8d...m4a"}, # 仅作占位，如无效会提示
        ]
        # 只取前 5
        test_list = news_list[:5]
    else:
        test_list = news_list[:5]
        
    for index, item in enumerate(test_list):
        print(f"\n[{index+1}/{len(test_list)}]")
        process_article(item)
        
    print("\n🎉 全部抓取流程执行完成！")


if __name__ == "__main__":
    main()
