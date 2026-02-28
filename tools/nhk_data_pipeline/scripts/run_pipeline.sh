#!/bin/bash
# run_pipeline.sh - NHK 数据管道一键执行脚本
# 用法: ./run_pipeline.sh --hdnts "<hdnts_token>"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PIPELINE_DIR"

echo "═══════════════════════════════════════"
echo "  NHK Easy News 数据管道 - 一键执行"
echo "═══════════════════════════════════════"
echo ""

# 解析参数
HDNTS_TOKEN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hdnts)
            HDNTS_TOKEN="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ===== 步骤 1: 爬虫 =====
echo "━━━ 步骤 1/4: 爬虫 (文本 + 音频下载) ━━━"
source venv/bin/activate

if [ -n "$HDNTS_TOKEN" ]; then
    python scripts/nhk_scraper.py --hdnts "$HDNTS_TOKEN"
else
    python scripts/nhk_scraper.py
fi

echo ""

# ===== 步骤 2: 音频对齐 =====
echo "━━━ 步骤 2/4: 音频对齐 (faster-whisper) ━━━"
python scripts/align.py
echo ""

# ===== 步骤 3: Kuromoji 分词 =====
echo "━━━ 步骤 3/5: Kuromoji 分词处理 ━━━"
node scripts/process_all.js
echo ""

# ===== 步骤 4: 机器翻译 (可选) =====
echo "━━━ 步骤 4/5: 机器翻译 (ZhipuAI) ━━━"
python scripts/translate_json.py
echo ""

# ===== 步骤 5: 部署到 App =====
echo "━━━ 步骤 5/5: 部署到 App Assets ━━━"
node scripts/convert_to_mock.js

# 复制音频文件到 mock 目录
MOCK_DIR="../../assets/mock"
mkdir -p "$MOCK_DIR"
for mp3 in data/*/*.mp3; do
    if [ -f "$mp3" ]; then
        cp "$mp3" "$MOCK_DIR/"
    fi
done

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ 管道执行完成！"
echo "═══════════════════════════════════════"

# 验证数据完整性
echo ""
echo "📊 数据完整性检查:"
python3 << 'PYEOF'
import json, os
data_dir = 'data'
for name in sorted(os.listdir(data_dir)):
    d = os.path.join(data_dir, name)
    if not os.path.isdir(d): continue
    raw_p = os.path.join(d, 'raw.json')
    proc_p = os.path.join(d, 'processed.json')
    aligned_p = os.path.join(d, 'aligned.json')
    if not os.path.exists(raw_p) or not os.path.exists(proc_p): continue
    raw = json.load(open(raw_p))
    proc = json.load(open(proc_p))
    has_aligned = os.path.exists(aligned_p)
    has_ts = any(s.get('start_ms') is not None for s in proc['sentences'])
    time_val = raw.get('time', 'N/A')
    has_audio = any(f.endswith('.mp3') for f in os.listdir(d))
    match = '✅' if len(raw['sentences']) == len(proc['sentences']) else '❌'
    ts_icon = '✅' if has_ts else '⚠️'
    aligned_icon = '✅' if has_aligned else '❌'
    audio_icon = '✅' if has_audio else '❌'
    print(f'  {match} {name}: {len(raw["sentences"])}句 | 音频:{audio_icon} | 对齐:{aligned_icon} | 时间戳:{ts_icon} | time:{time_val}')
PYEOF
