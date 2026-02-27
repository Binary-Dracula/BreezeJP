import os
import json
import re
from faster_whisper import WhisperModel
import subprocess

# --- 配置参数 ---
JSON_FILE = "data/test_output.json"
OUTPUT_DIR = "output"
# 采用 small 模型即可满足清晰日语新闻的识别，权衡速度和准确率
MODEL_SIZE = "small" 

print("⏳ 正在加载 Whisper 模型 (初次运行会自动下载权重文件)...")
model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
print("✅ 加载完成。")

def get_audio_metadata(file_path):
    """获取音频文件的大小和时长"""
    try:
        size = os.path.getsize(file_path)
        # 使用 ffprobe 获取精确时长 (毫秒)
        cmd = [
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration", "-of",
            "default=noprint_wrappers=1:nokey=1", file_path
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True)
        duration_sec = float(result.stdout.strip())
        duration_ms = int(duration_sec * 1000)
        return size, duration_ms
    except Exception as e:
        print(f"⚠️ 获取元数据失败: {e}")
        return 0, 0

def clean_furigana_text(text):
    """移除 [假名] 以便与 Whisper 的纯文本输出对比 / 检查"""
    return re.sub(r'\[.*?\]', '', text)

def smart_split_sentences(paragraphs):
    """
    智能切分段落为句子。
    规则: 按 。？！ 切分，但保留右侧的下引号 ” 或 」
    由于 NHK 文本特点，这里主要针对 '。' 和 '」'
    同时处理超长句子。
    """
    raw_sentences = []
    
    # 1. 第一层切分: 智能标点切分
    # 匹配非句号问号等，直到遇到一个句号，且后面可能跟着」
    pattern = r'([^。？！]*[。？！]」?)'
    
    for p in paragraphs:
        # 去除多余空格
        p = p.strip()
        if not p: continue
        
        # 尝试正则切分
        parts = re.split(pattern, p)
        for part in parts:
            part = part.strip()
            if part:
                raw_sentences.append(part)
                
    # 2. 第二层切分: 长句打断 (PM 需求)
    final_items = []
    index = 0
    for s in raw_sentences:
        # 估算词数/字符数。日文主要看字符数，包含假名的原文本如果超过 45 个字符(约15个词)，尝试按 、 切分
        if len(s) > 45 and "、" in s:
            # 找到最中间的 、 或直接按 、 全切 (这里采用简单的全顿号缓切)
            sub_parts = s.split("、")
            for i, sub in enumerate(sub_parts):
                is_last = (i == len(sub_parts) - 1)
                # 补回顿号
                sub_text = sub + "、" if not is_last else sub
                
                final_items.append({
                    "text": sub_text,
                    "translation": "",
                    "start_ms": 0,
                    "end_ms": 0,
                    "is_split_sentence": not is_last, # PM 需求: 视觉连接符
                    "index": index
                })
                index += 1
        else:
            final_items.append({
                "text": s,
                "translation": "",
                "start_ms": 0,
                "end_ms": 0,
                "is_split_sentence": False,
                "index": index
            })
            index += 1
            
    return final_items

def align_audio_to_items(mp3_path, items, duration_ms):
    """
    使用 Whisper 获取 word 级时间戳，并映射分配给 items。
    """
    print(f"  🎙️ 开始转录与对齐: {mp3_path}")
    # 启用 word_timestamps 获得更高的精度颗粒度
    segments, info = model.transcribe(mp3_path, language="ja", beam_size=5, word_timestamps=True)
    
    # 收集所有的 word 级对齐数据
    all_words = []
    for segment in segments:
        if segment.words:
            for word in segment.words:
                all_words.append({
                    "word": word.word,
                    "start": int(word.start * 1000),
                    "end": int(word.end * 1000)
                })
        else:
            # Fallback 如果没有 words (非常罕见)
            all_words.append({
                "word": segment.text,
                "start": int(segment.start * 1000),
                "end": int(segment.end * 1000)
            })

    if not all_words:
        print("  ❌ Whisper 未能提取任何词汇级片段。")
        return False

    # 我们有 items，每个 item 有特定的字符数
    # 我们有 all_words，每个 word 有时间戳
    # 策略：总纯字符数映射。
    
    clean_items = [clean_furigana_text(item["text"]) for item in items]
    total_text_chars = sum(len(c) for c in clean_items)
    
    # 组装所有 whisper 识别出来的字符串用于比例计算
    whisper_full_text = "".join(w["word"] for w in all_words)
    total_whisper_chars = len(whisper_full_text)
    
    if total_text_chars == 0 or total_whisper_chars == 0:
        return False

    # 在单词级数组上通过累积字符比例来切分
    current_char_offset = 0
    word_idx = 0
    
    for i, item in enumerate(items):
        item_char_len = len(clean_items[i])
        target_char_end = current_char_offset + item_char_len
        
        # 寻找对应的起始 word
        while word_idx < len(all_words) and current_char_offset >= len("".join(w["word"] for w in all_words[:word_idx+1])):
             word_idx += 1
             
        start_word = all_words[min(word_idx, len(all_words)-1)]
        start_ms = start_word["start"]
        
        # 寻找对应的结束 word
        end_word_idx = word_idx
        while end_word_idx < len(all_words) and target_char_end > len("".join(w["word"] for w in all_words[:end_word_idx+1])):
            end_word_idx += 1
            
        end_word = all_words[min(end_word_idx, len(all_words)-1)]
        end_ms = end_word["end"]
        
        # 更新游标
        current_char_offset = target_char_end
        word_idx = end_word_idx
        
        # 缓冲优化 (PM 需求)
        pad_start = 50
        pad_end = 80
        
        start_ms = max(0, start_ms - pad_start)
        
        # 如果是最后一句，确保留白并且不超出物理声音极限
        if i == len(items) - 1:
            end_ms = duration_ms
        else:
            end_ms = end_ms + pad_end
            
        item["start_ms"] = int(start_ms)
        item["end_ms"] = int(end_ms)
        
    return True

def main():
    if not os.path.exists(JSON_FILE):
        print(f"❌ 找不到文件 {JSON_FILE}")
        return

    with open(JSON_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        news_id = item.get("id")
        print(f"\n🔄 处理: {news_id} ({item.get('title')})")
        
        mp3_path = item.get("audio_uri")
        if not mp3_path or not os.path.exists(mp3_path):
            print(f"  ❌ 未找到音频文件: {mp3_path}")
            item["has_sync_data"] = False
            continue
            
        # 1. Metadata
        size, duration = get_audio_metadata(mp3_path)
        item["audio_size"] = size
        item["duration_ms"] = duration
        print(f"  📊 元数据: {size} 字节, {duration} ms")
        
        # 2. 段落切分成原子 items
        paragraphs = item.get("paragraphs", [])
        if paragraphs:
            new_items = smart_split_sentences(paragraphs)
            
            # 3. Whisper 时间戳对齐
            success = align_audio_to_items(mp3_path, new_items, duration)
            item["has_sync_data"] = success
            item["items"] = new_items
            
            # 移除旧的 paragraphs
            del item["paragraphs"]
            print(f"  ✅ 拆分并对齐了 {len(new_items)} 个句子")
        else:
            print("  ⚠️ 没有 paragraphs 文本")
            item["has_sync_data"] = False

    # 保存新的 JSON
    output_json = "data/aligned_test_output.json"
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 完毕！已生成 {output_json}")

if __name__ == "__main__":
    main()
