#!/bin/bash

# 新标日初级下册 上传脚本

source .venv/bin/activate

echo "🚀 开始上传: 新标日初级下册"
echo "📊 预估词数: 1297"
echo ""

python .agents/skills/japanese-vocab-generator/scripts/upload_words.py \
  --ai-json "files/单词生成器/输出结果/新标日初级下册_latest.json" \
  --moji-json "files/单词生成器/单词源/新标日初级下册/words.json" \
  --book-title "新标日初级下册"

echo ""
echo "✅ 新标日初级下册 上传完成"
