#!/bin/bash
# 从项目数据库导出 kana_audio 数据到外部数据库

SOURCE_DB="/Users/summer/work/money/breeze_jp/assets/database/breeze_jp.sqlite"
TARGET_DB="/Users/summer/work/database/BreezeJP/breeze_jp.sqlite"

echo "源数据库: $SOURCE_DB"
echo "目标数据库: $TARGET_DB"

# 清空目标表
sqlite3 "$TARGET_DB" "DELETE FROM kana_audio;"
echo "已清空目标表 kana_audio"

# 导出并导入
sqlite3 "$SOURCE_DB" ".mode insert kana_audio" ".output /tmp/kana_audio_dump.sql" "SELECT * FROM kana_audio;"
sqlite3 "$TARGET_DB" < /tmp/kana_audio_dump.sql

# 验证
source_count=$(sqlite3 "$SOURCE_DB" "SELECT COUNT(*) FROM kana_audio;")
target_count=$(sqlite3 "$TARGET_DB" "SELECT COUNT(*) FROM kana_audio;")

echo ""
echo "=== 完成 ==="
echo "源数据库记录: $source_count 条"
echo "目标数据库记录: $target_count 条"

rm /tmp/kana_audio_dump.sql
