"""
align.py - 批量音频对齐脚本
遍历 data/{id}/ 目录，读取 raw.json + 音频文件，
使用 faster-whisper + Needleman-Wunsch DP 生成句子级时间戳，
输出到 data/{id}/aligned.json
"""
import json
import re
import os
import sys
import math
from typing import List, Dict, Any


def levenshtein_align(whisper_words: List[Dict], sentences: List[str]):
    """
    使用 Needleman-Wunsch DP 将 Whisper 识别的词对齐到标准句子，
    在字符级别进行匹配。
    """
    # 清理句子（移除假名注音和标点）
    clean_sentences = []
    for s in sentences:
        s = re.sub(r'\[.*?\]', '', s)
        s = re.sub(r'[。、！？\s]+', '', s)
        clean_sentences.append(s)
    standard_chars = "".join(clean_sentences)
    
    # 清理 Whisper 词
    clean_words = []
    for w in whisper_words:
        text = w['word'].strip()
        text = re.sub(r'[。、！？\s]+', '', text)
        if text:
            clean_words.append({'text': text, 'start': w['start'], 'end': w['end']})
            
    whisper_chars = "".join([w['text'] for w in clean_words])
    
    n = len(standard_chars)
    m = len(whisper_chars)
    
    if n == 0 or m == 0:
        return [{"start_ms": 0, "end_ms": 0, "text": s, "index": i} for i, s in enumerate(sentences)]
    
    # DP 对齐
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1): dp[i][0] = i
    for j in range(1, m + 1): dp[0][j] = j
        
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if standard_chars[i - 1] == whisper_chars[j - 1] else 1
            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
            
    # 回溯找映射
    i, j = n, m
    mapping = {}
    while i > 0 and j > 0:
        cost = 0 if standard_chars[i - 1] == whisper_chars[j - 1] else 1
        if dp[i][j] == dp[i - 1][j - 1] + cost:
            mapping[i - 1] = j - 1
            i -= 1; j -= 1
        elif dp[i][j] == dp[i - 1][j] + 1:
            i -= 1
        else:
            j -= 1
            
    # 词的字符位置累加表
    word_start_char_idx = []
    acc = 0
    for w in clean_words:
        word_start_char_idx.append(acc)
        acc += len(w['text'])
        
    # 将映射转化为句子级时间戳
    aligned_sentences = []
    current_char_idx = 0
    
    for idx, (clean_sentence, original_sentence) in enumerate(zip(clean_sentences, sentences)):
        sentence_len = len(clean_sentence)
        start_char = current_char_idx
        end_char = current_char_idx + sentence_len - 1
        
        start_whisper_idx = -1
        end_whisper_idx = -1
        
        for c in range(start_char, end_char + 1):
            if c in mapping:
                mapped_char = mapping[c]
                for w_idx, w_start in enumerate(word_start_char_idx):
                    if mapped_char >= w_start and mapped_char < w_start + len(clean_words[w_idx]['text']):
                        start_whisper_idx = w_idx
                        break
                if start_whisper_idx != -1: break
                    
        for c in range(end_char, start_char - 1, -1):
            if c in mapping:
                mapped_char = mapping[c]
                for w_idx, w_start in enumerate(word_start_char_idx):
                    if mapped_char >= w_start and mapped_char < w_start + len(clean_words[w_idx]['text']):
                        end_whisper_idx = w_idx
                        break
                if end_whisper_idx != -1: break
        
        start_ms = 0
        end_ms = 0
        
        if start_whisper_idx != -1 and end_whisper_idx != -1:
            start_ms = int(clean_words[start_whisper_idx]['start'] * 1000)
            end_ms = int(clean_words[end_whisper_idx]['end'] * 1000)
        elif start_whisper_idx != -1:
            start_ms = int(clean_words[start_whisper_idx]['start'] * 1000)
            end_ms = start_ms + 1000
        elif aligned_sentences:
            start_ms = aligned_sentences[-1]['end_ms']
            end_ms = start_ms + 1500
        else:
            end_ms = 1500
            
        if aligned_sentences and start_ms < aligned_sentences[-1]['end_ms']:
            start_ms = aligned_sentences[-1]['end_ms']
            if end_ms < start_ms: end_ms = start_ms + 100
        
        aligned_sentences.append({
            "start_ms": start_ms,
            "end_ms": end_ms,
            "text": original_sentence,
            "translation": "",
            "index": idx
        })
        current_char_idx += sentence_len
        
    return aligned_sentences


def process_article(article_dir, model):
    """处理单篇文章的音频对齐"""
    raw_path = os.path.join(article_dir, 'raw.json')
    aligned_path = os.path.join(article_dir, 'aligned.json')
    
    if not os.path.exists(raw_path):
        return False
    
    raw_data = json.load(open(raw_path, encoding='utf-8'))
    article_id = raw_data['id']
    sentences = raw_data.get('sentences', [])
    audio_uri = raw_data.get('audio_uri', '')
    
    if not sentences:
        print(f"  ⏭️ {article_id}: 无句子数据")
        return False
    
    # 查找音频文件（统一存放在 data/{id}/ 目录下）
    audio_path = None
    for f in os.listdir(article_dir):
        if f.endswith('.mp3') or f.endswith('.m4a'):
            audio_path = os.path.join(article_dir, f)
            break
    
    if not audio_path or not os.path.exists(audio_path):
        print(f"  ⏭️ {article_id}: 音频文件不存在")
        return False
    
    print(f"  🔄 对齐 {article_id}: {len(sentences)} 句, 音频 {audio_path}")
    
    # Whisper 转录
    from mutagen.mp3 import MP3
    segments, info = model.transcribe(audio_path, language="ja", word_timestamps=True)
    
    whisper_words = []
    for segment in segments:
        for word in segment.words:
            whisper_words.append({"word": word.word, "start": word.start, "end": word.end})
    
    print(f"    Whisper 识别到 {len(whisper_words)} 个词")
    
    # 对齐
    aligned_items = levenshtein_align(whisper_words, sentences)
    
    # 获取音频时长
    audio_info = MP3(audio_path)
    duration_ms = int(audio_info.info.length * 1000)
    
    # 输出
    aligned_data = {
        "id": article_id,
        "duration_ms": duration_ms,
        "items": aligned_items
    }
    
    with open(aligned_path, 'w', encoding='utf-8') as f:
        json.dump(aligned_data, f, ensure_ascii=False, indent=2)
    
    print(f"  ✅ → {article_id}/aligned.json ({len(aligned_items)} 句, 总时长 {duration_ms}ms)")
    return True


def main():
    print("🚀 音频对齐处理（批量）")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pipeline_dir = os.path.dirname(script_dir)
    data_dir = os.path.join(pipeline_dir, 'data')
    
    if not os.path.exists(data_dir):
        print(f"❌ 数据目录不存在: {data_dir}")
        sys.exit(1)
    
    # 扫描所有文章文件夹
    article_dirs = []
    for name in sorted(os.listdir(data_dir)):
        d = os.path.join(data_dir, name)
        if os.path.isdir(d) and os.path.exists(os.path.join(d, 'raw.json')):
            article_dirs.append(d)
    
    print(f"📂 发现 {len(article_dirs)} 篇文章\n")
    
    if not article_dirs:
        print("⚠️ 未找到任何文章数据")
        return
    
    # 加载 Whisper 模型（只加载一次）
    from faster_whisper import WhisperModel
    print("⏳ 载入 faster-whisper 模型...")
    model = WhisperModel("small", device="cpu", compute_type="int8")
    print("✅ 模型加载完成\n")
    
    success = 0
    for d in article_dirs:
        if process_article(d, model):
            success += 1
    
    print(f"\n🎉 对齐完成！成功 {success}/{len(article_dirs)} 篇")


if __name__ == "__main__":
    main()
