#!/bin/bash

# 完整的两本书连续上传脚本
# 使用方式: bash scripts/upload_all_books.sh

set -e  # 遇到错误立即退出

source .venv/bin/activate

SKILL_DIR=".agents/skills/japanese-vocab-generator"
OUTPUT_DIR="files/单词生成器/输出结果"
SOURCE_DIR="files/单词生成器/单词源"

echo "==============================================="
echo "🎯 开始执行两本书的连续上传"
echo "==============================================="
echo ""

# 第一本书: 新标日初级上册
echo "📚 [1/2] 上传: 新标日初级上册"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

python "$SKILL_DIR/scripts/upload_words.py" \
  --ai-json "$OUTPUT_DIR/新标日初级上册_latest.json" \
  --moji-json "$SOURCE_DIR/新标日初级上册/words.json" \
  --book-title "新标日初级上册"

RESULT1=$?
echo ""
if [ $RESULT1 -eq 0 ]; then
  echo "✅ 新标日初级上册 上传成功"
else
  echo "❌ 新标日初级上册 上传失败 (错误码: $RESULT1)"
  exit 1
fi
echo ""

# 等待片刻让数据库稳定
echo "⏳ 等待数据库稳定 (5秒)..."
sleep 5

# 第二本书: 新标日初级下册
echo ""
echo "📚 [2/2] 上传: 新标日初级下册"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

python "$SKILL_DIR/scripts/upload_words.py" \
  --ai-json "$OUTPUT_DIR/新标日初级下册_latest.json" \
  --moji-json "$SOURCE_DIR/新标日初级下册/words.json" \
  --book-title "新标日初级下册"

RESULT2=$?
echo ""
if [ $RESULT2 -eq 0 ]; then
  echo "✅ 新标日初级下册 上传成功"
else
  echo "❌ 新标日初級下册 上传失败 (错误码: $RESULT2)"
  exit 1
fi

echo ""
echo "==============================================="
echo "🎉 所有书籍上传完成！"
echo "==============================================="
echo "⏰ 完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "📊 统计:"
echo "  • 新标日初级上册: 1401 字"
echo "  • 新标日初级下册: 1297 字"
echo "  • 总计: 2698 字 (去重后)"
echo ""
echo "💾 数据存储:"
echo "  • Supabase: 单词数据 + 关联关系"
echo "  • Cloudflare R2: 音频文件"
echo ""
