import json
import os
import subprocess

# 配置
JSON_FILE = "test_output.json"
OUTPUT_DIR = "output"

# 包含有效的 hdnts Token 的 m3u8 完整列表 (从浏览器网络请求获取)
VALID_M3U8_URLS = {
    "ne2026022011579": "https://media.vd.st.nhk/news/easy_audio/ne2026022011579_EIqPYPjRzbruIPe6yXQ4WDDIpeQQjt8C7C4SsMM2/index.m3u8?hdnts=exp=1771679028~acl=/*~hmac=6cdfe0cd402b20c512e77597efd8bb28f775688a7b802d476a3130e0a04c37c7",
    "ne2026022011598": "https://media.vd.st.nhk/news/easy_audio/ne2026022011598_obCizmPLjQjx1tT0GMUGGcKUq4tJDm8DQw5VZHg3/index.m3u8?hdnts=exp=1771679028~acl=/*~hmac=6cdfe0cd402b20c512e77597efd8bb28f775688a7b802d476a3130e0a04c37c7",
    "ne2026022012025": "https://media.vd.st.nhk/news/easy_audio/ne2026022012025_brmMKl7jpgbtu3Q03uDT2nv4I3Qnjqn2WLIVNZ4y/index.m3u8?hdnts=exp=1771679323~acl=/*~hmac=3d96871ac0ac65493c2df2de37778d053a393dc68736087a4baffbb5ae17660e",
    "ne2026022012083": "https://media.vd.st.nhk/news/easy_audio/ne2026022012083_ihz5saiOoanB0ap3XTjl9rGsIjxrCPpN3Bg7rOB9/index.m3u8?hdnts=exp=1771679323~acl=/*~hmac=3d96871ac0ac65493c2df2de37778d053a393dc68736087a4baffbb5ae17660e",
    "ne2026021911520": "https://media.vd.st.nhk/news/easy_audio/ne2026021911520_RtGM3ITFnhBwHdvjEGSos1wdX8r6gPaBJFJaL7i3/index.m3u8?hdnts=exp=1771679323~acl=/*~hmac=3d96871ac0ac65493c2df2de37778d053a393dc68736087a4baffbb5ae17660e"
}

def download_audio(news_id, m3u8_url):
    article_dir = os.path.join(OUTPUT_DIR, news_id)
    os.makedirs(article_dir, exist_ok=True)
    mp3_path = os.path.join(article_dir, f"{news_id}.mp3")

    if os.path.exists(mp3_path):
        print(f"  ⏭️ {news_id}.mp3 已存在，跳过。")
        return mp3_path

    print(f"🔽 正在下载音频: {news_id}")
    
    headers = "Referer: https://news.web.nhk/\r\nOrigin: https://news.web.nhk\r\nUser-Agent: Mozilla/5.0\r\n"
    
    cmd = [
        "ffmpeg", 
        "-y",
        "-headers", headers,
        "-i", m3u8_url, 
        "-c:a", "libmp3lame",
        "-b:a", "128k",
        "-hide_banner", 
        "-loglevel", "error", 
        mp3_path
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"  ✅ 下载成功: {mp3_path}")
        return mp3_path
    except subprocess.CalledProcessError as e:
        print(f"  ❌ 下载失败: {e}")
        return None

def main():
    if not os.path.exists(JSON_FILE):
        print("❌ 未找到 test_output.json")
        return

    with open(JSON_FILE, "r", encoding="utf-8") as f:
        articles = json.load(f)

    for item in articles:
        news_id = item.get("id")
        m3u8_url = VALID_M3U8_URLS.get(news_id)
        
        if m3u8_url and news_id:
            mp3_path = download_audio(news_id, m3u8_url)
            if mp3_path:
                # 只保留本地路径字段，原来的 audio_uri (带有易过期的 token) 可以选择保留或替换
                item["local_audio_path"] = f"output/{news_id}/{news_id}.mp3"
                item["audio_uri"] = f"output/{news_id}/{news_id}.mp3" # 替换掉无法直接播放的 M3U8

    with open(JSON_FILE, "w", encoding="utf-8") as f:
        json.dump(articles, f, ensure_ascii=False, indent=2)

    print("\n🎉 音频处理完成。")

if __name__ == "__main__":
    main()
