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
Z_AT_TOKEN = "eyJhbGciOiJFUzI1NiIsInR5cCI6ImF0K2p3dCIsImtpZCI6ImtpZC1hdXRoei1hYzEtcHJkLTAxIn0.eyJzdWIiOiIyMjA3MjExOS1mOWJlLTRlMDUtOTlhZi0wNWJhMTgyZjY0ZTkiLCJpc3MiOiJodHRwczovL2EuYXV0aHouYWMxLm5oayIsImFjdGl2YXRlZEJ5Ijoic2VsZi1hY3RpdmF0ZWQiLCJjbGllbnRfaWQiOiIyOTM3ODU4NDExOCIsImxpY2Vuc2VUeXBlIjoiMCIsInByb2ZpbGVUeXBlIjoiYWJyb2FkIiwiZ3JhbnRfdHlwZSI6ImF1dGhvcml6YXRpb25fY29kZSIsInByb2ZpbGVJZCI6IjIyMDcyMTE5LWY5YmUtNGUwNS05OWFmLTA1YmExODJmNjRlOSIsInNjb3BlIjoiZ2V0Om5ld3MgZ2V0OnR2IiwiZXhwIjoxNzczMzQ5NTQxLCJpYXQiOjE3NzMzMjA3NDEsImVudGl0eSI6Im5vbmUgaG91c2Vob2xkIiwianRpIjoiZmpRRWNpcWFmVDZ6TzQwdXhPdUhmUzE1Q01Db0NoX28xS3FraHpSeHFhVSJ9.Y3yl16PujMdn5xY7_ahi2nZ-26axvvw6E7yeFq92N1aHnVmwlTRbe62jlLhliJU6pW676oCrSw-nKTOYrDwd9w"

# 文件保存目录
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PIPELINE_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(PIPELINE_DIR, "data")

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
        cmd = ['curl', '-s', '-H', f'User-Agent: {HEADERS["User-Agent"]}', '-H', f'Cookie: {HEADERS["Cookie"]}', NEWS_LIST_URL]
        res = subprocess.run(cmd, capture_output=True, text=True)
        
        if not res.stdout or "<title>403 Forbidden</title>" in res.stdout:
            print(f"❌ 授权失败 (403)。请检查 Z_AT_TOKEN 是否过期。")
            return []
            
        content = res.stdout.strip("\ufeff")
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


def get_media_token():
    """获取播放音频需要的 hdnts Token
    
    由于 mediatoken.web.nhk 域名在当前网络环境下可能无法直接访问，
    支持以下获取方式（按优先级）：
    1. 命令行参数 --hdnts <token>
    2. 环境变量 NHK_HDNTS_TOKEN
    3. 直接调用 mediatoken API（需要网络可达）
    """
    import sys
    
    # 方式1: 命令行参数
    for i, arg in enumerate(sys.argv):
        if arg == '--hdnts' and i + 1 < len(sys.argv):
            token = sys.argv[i + 1]
            print(f"✅ 使用命令行传入的 hdnts Token")
            return token
    
    # 方式2: 环境变量
    env_token = os.environ.get('NHK_HDNTS_TOKEN', '')
    if env_token:
        print(f"✅ 使用环境变量 NHK_HDNTS_TOKEN")
        return env_token
    
    # 方式3: 直接调用 API
    try:
        url = "https://mediatoken.web.nhk/v1/token"
        cmd = ['curl', '-s', '--connect-timeout', '5', '-H', f'Authorization: Bearer {Z_AT_TOKEN}', url]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if res.stdout.strip():
            data = json.loads(res.stdout)
            token = data.get("token", "")
            if token:
                print(f"✅ 从 mediatoken API 获取到 hdnts Token")
                return token
    except Exception as e:
        pass
    
    print("⚠️ 无法获取 hdnts Token。音频下载将跳过。")
    print("   解决方案：通过浏览器获取 hdnts Token 后使用 --hdnts 参数传入")
    return ""

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


def split_into_sentences(paragraph):
    """将段落按句号拆分为句子列表"""
    # 按 。 拆分，保留句号
    raw = re.split(r'(。)', paragraph)
    sentences = []
    for part in raw:
        if part == '。':
            if sentences:
                sentences[-1] += '。'
            else:
                sentences.append('。')
        elif part.strip():
            sentences.append(part)
    return sentences


def download_audio(news_id, voice_uri, output_path, media_token):
    """下载音频文件"""
    if not voice_uri:
        return None
        
    if os.path.exists(output_path):
        print(f"  ⏭️ 音频已存在。")
        return output_path

    mp3_path = output_path.replace(".m4a", ".mp3")
    if os.path.exists(mp3_path):
        print(f"  ⏭️ 音频已存在。")
        return mp3_path

    # 新版 NHK 移除了 m4a 直接下载，改为带 hdnts token 的 m3u8 playlist
    voice_dir_name = voice_uri.replace(".m4a", "")
    m3u8_url = f"https://media.vd.st.nhk/news/easy_audio/{voice_dir_name}/index.m3u8?hdnts={media_token}"

    print(f"  🔽 尝试使用 ffmpeg 下载音频文件: {m3u8_url.split('?')[0]}")
    
    cmd = [
        "ffmpeg", "-y", 
        "-headers", f"User-Agent: {HEADERS['User-Agent']}\r\nReferer: https://news.web.nhk/\r\n",
        "-i", m3u8_url, "-c:a", "libmp3lame", "-b:a", "128k",
        "-hide_banner", "-loglevel", "error", mp3_path
    ]
    try:
        subprocess.run(cmd, check=True)
        print(f"  ✅ 音频转换完成 (mp3)。")
        return mp3_path
    except:
        print(f"  ❌ 音频下载彻底失败。")
        return None


def process_article(news_item, media_token):
    """处理单篇新闻，输出到 data/{id}/raw.json"""
    news_id = news_item.get("news_id")
    if not news_id: return

    # 文章目录（所有产物统一放在 data/{id}/ 下）
    article_dir = os.path.join(DATA_DIR, news_id)
    os.makedirs(article_dir, exist_ok=True)
    audio_path = os.path.join(article_dir, f"{news_id}.m4a")
    raw_json_path = os.path.join(article_dir, "raw.json")

    print(f"🔄 处理新闻: {news_item.get('title')} ({news_id})")

    # 获取 HTML
    article_url = f"{BASE_URL}{news_id}/{news_id}.html"
    try:
        cmd = ['curl', '-s', '-H', f'User-Agent: {HEADERS["User-Agent"]}', '-H', f'Cookie: {HEADERS["Cookie"]}', article_url]
        res = subprocess.run(cmd, capture_output=True, text=True)
        
        if not res.stdout or "<title>403 Forbidden</title>" in res.stdout:
            print(f"  ❌ 文章无法访问 (HTTP 403)。")
            return
        
        soup = BeautifulSoup(res.stdout, "html.parser")
    except Exception as e:
        print(f"  ❌ 获取文章失败: {e}")
        return

    # 解析标题
    title_element = soup.select_one("h1.article-title")
    title_furigana = parse_furigana(title_element) or news_item.get("title")
    # 移除 [假名] 得到纯净标题
    clean_title = re.sub(r'\[.*?\]', '', title_furigana)

    # 解析正文段落，然后按句号拆分为句子
    body_element = soup.select_one("#js-article-body")
    sentences = []
    if body_element:
        for p in body_element.find_all("p"):
            text = parse_furigana(p)
            if text.strip():
                # 将段落按句号拆分为独立句子
                paragraph_sentences = split_into_sentences(text)
                sentences.extend(paragraph_sentences)
    
    # 音频下载
    final_audio_path = None
    voice_uri = news_item.get("news_easy_voice_uri")
    if voice_uri:
        final_audio_path = download_audio(news_id, voice_uri, audio_path, media_token)
    else:
        print(f"  ℹ️ 无音频。")

    relative_audio_uri = ""
    if final_audio_path:
        relative_audio_uri = os.path.relpath(final_audio_path, PIPELINE_DIR)

    # 获取文章时间：优先使用 news_prearranged_time，其次 news_time
    article_time = news_item.get("news_prearranged_time") or news_item.get("news_time") or None

    article_data = {
        "id": news_id,
        "title": title_furigana,
        "clean_title": clean_title,
        "time": article_time,
        "audio_uri": relative_audio_uri,
        "sentences": sentences
    }

    with open(raw_json_path, "w", encoding="utf-8") as f:
        json.dump(article_data, f, ensure_ascii=False, indent=2)
    print(f"  ✅ 文本解析完成 → data/{news_id}/raw.json ({len(sentences)} 句)")

    return article_data


def main():
    print("🚀 NHK News Web Easy 爬虫 (新版架构)")
    os.makedirs(DATA_DIR, exist_ok=True)
    check_ffmpeg()
    
    news_list = get_news_list()
    if not news_list:
        print("⚠️ 无法获取列表，使用测试数据运行...")
        news_list = [
            {"news_id": "ne2026022011579", "title": "高市総理大臣　これからどんな政治をするか考え方を話した", "news_prearranged_time": "2026-02-20T15:30:00+09:00", "news_easy_voice_uri": "ne2026022011579_EIqPYPjRzbruIPe6yXQ4WDDIpeQQjt8C7C4SsMM2.m4a"},
        ]
        test_list = news_list[:3]
    else:
        test_list = news_list[:3]
        
    success_count = 0
    
    media_token = get_media_token()
    if not media_token:
        print("⚠️ 获取不到媒体 Token，音频可能无法下载！")
        
    for index, item in enumerate(test_list):
        print(f"\n[{index+1}/{len(test_list)}]")
        res = process_article(item, media_token)
        if res:
            success_count += 1
            
    print(f"\n🎉 全部抓取流程执行完成！成功处理 {success_count} 篇文章，数据已保存到 data/{{article_id}}/raw.json")


if __name__ == "__main__":
    main()
