#!/bin/bash

# 监控上传进度脚本
# 定期检查第一本书的上传进度
# 当第一本完成时，自动启动第二本的上传

PROCESS_ID="${1:-3eec4c6c-bbff-4e51-91af-06e9d493bed7}"
SECOND_BOOK_CMD="${2:-source .venv/bin/activate && python .agents/skills/japanese-vocab-generator/scripts/upload_words.py --ai-json \"files/单词生成器/输出结果/新标日初级下册_latest.json\" --moji-json \"files/单词生成器/单词源/新标日初级下册/words.json\" --book-title \"新标日初级下册\"}"

echo "🔍 开始监控上传进度..." 
echo "📌 进程 ID: $PROCESS_ID"
echo "⏱️  每 60 秒检查一次进度"
echo ""

check_count=0
while true; do
  check_count=$((check_count+1))
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  echo "[$timestamp] 检查 #$check_count..."
  
  # 这里应该集成实际的进度检查逻辑
  # 对于现在，我们只输出提示
  echo "  ℹ️  使用 'get_terminal_output' 检查进程 $PROCESS_ID 的最新输出"
  echo ""
  
  # 等待 60 秒
  # 如果第一本完成，应该启动第二本
  
  sleep 60
done
