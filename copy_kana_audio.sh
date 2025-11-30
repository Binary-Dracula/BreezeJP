#!/bin/bash
# 复制下载的五十音音频到项目目录，处理罗马音映射

SOURCE_DIR="/Users/summer/Downloads/50yin/learn50"
TARGET_DIR="assets/audio/kana"
DB_PATH="assets/database/breeze_jp.sqlite"

mkdir -p "$TARGET_DIR"

# 罗马音映射函数
get_source_name() {
    case "$1" in
        shi) echo "si" ;;
        chi) echo "ci" ;;
        tsu) echo "cu" ;;
        fu) echo "hu" ;;
        ji) echo "zi" ;;
        sha) echo "sya" ;;
        shu) echo "syu" ;;
        sho) echo "syo" ;;
        cha) echo "cya" ;;
        chu) echo "cyu" ;;
        cho) echo "cyo" ;;
        ja) echo "zya" ;;
        ju) echo "zyu" ;;
        jo) echo "zyo" ;;
        *) echo "$1" ;;
    esac
}

# 清空目标目录
rm -f "$TARGET_DIR"/*.mp3 "$TARGET_DIR"/*.wav

# 读取数据库中的 romaji
sqlite3 "$DB_PATH" "SELECT DISTINCT romaji FROM kana_letters WHERE romaji IS NOT NULL AND romaji != '' AND romaji != 'long vowel';" | while read -r romaji; do
    source_name=$(get_source_name "$romaji")
    source_file="${SOURCE_DIR}/${source_name}.mp3"
    target_file="${TARGET_DIR}/${romaji}.mp3"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$target_file"
        echo "✓ $romaji <- ${source_name}.mp3"
    else
        echo "✗ 缺失: $romaji (尝试: ${source_name}.mp3)"
    fi
done

echo ""
echo "=== 完成 ==="
echo "目标目录文件数: $(ls -1 $TARGET_DIR/*.mp3 2>/dev/null | wc -l)"
