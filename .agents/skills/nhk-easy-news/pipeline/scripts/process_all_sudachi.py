#!/usr/bin/env python3
"""
process_all_sudachi.py
遍历 data/ 下所有文章文件夹，读取 raw.json，
用 SudachiPy 分词处理，输出 processed.json
确保 processed.json 的 sentences 数量与 raw.json 严格一致

用法:
    python scripts/process_all_sudachi.py              # 默认 Mode B
    python scripts/process_all_sudachi.py --mode A     # 最短单位
    python scripts/process_all_sudachi.py --mode C     # 最长单位（命名实体级别）
"""

import argparse
import json
import os
import re
import sys

from sudachipy import Dictionary, SplitMode

# ──────────────────────────────────────────────
# 常量
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PIPELINE_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(PIPELINE_DIR, 'data')

SPLIT_MODE_MAP = {
    'A': SplitMode.A,
    'B': SplitMode.B,
    'C': SplitMode.C,
}

# ──────────────────────────────────────────────
# 工具函数
# ──────────────────────────────────────────────

# 汉字 Unicode 范围（CJK 统一汉字 + 々）
KANJI_RE = re.compile(r'[\u4e00-\u9faf\u3005]')
# 片假名转平假名偏移量
KATAKANA_TO_HIRAGANA_OFFSET = 0x60


def katakana_to_hiragana(text: str) -> str:
    """片假名转平假名"""
    result = []
    for ch in text:
        code = ord(ch)
        # ァ(0x30A1) ~ ヶ(0x30F6)
        if 0x30A1 <= code <= 0x30F6:
            result.append(chr(code - KATAKANA_TO_HIRAGANA_OFFSET))
        else:
            result.append(ch)
    return ''.join(result)


def escape_regex(s: str) -> str:
    """转义正则特殊字符"""
    return re.escape(s)


def generate_ruby_text(surface_form: str, reading: str) -> str:
    """
    生成精确的 ruby_text 注音字符串。
    只在汉字部分标注假名，送假名/纯假名保持原样。
    例如:
        surface_form="増える", reading="フエル" → "増[ふ]える"
        surface_form="消費税", reading="ショウヒゼイ" → "消費税[しょうひぜい]"
        surface_form="総理",   reading="ソウリ" → "総理[そうり]"
    """
    if not KANJI_RE.search(surface_form):
        return surface_form
    if not reading:
        return surface_form

    hiragana_reading = katakana_to_hiragana(reading)

    # 将 surface_form 按汉字/非汉字交替拆分为段
    segments = []
    i = 0
    while i < len(surface_form):
        is_kanji = bool(KANJI_RE.match(surface_form[i]))
        seg = ''
        while i < len(surface_form) and bool(KANJI_RE.match(surface_form[i])) == is_kanji:
            seg += surface_form[i]
            i += 1
        segments.append({'text': seg, 'is_kanji': is_kanji})

    # 构建正则：汉字段 → 捕获组，非汉字段 → 字面量匹配
    last_kanji_idx = -1
    for j, seg in enumerate(segments):
        if seg['is_kanji']:
            last_kanji_idx = j

    regex_parts = []
    for j, seg in enumerate(segments):
        if seg['is_kanji']:
            regex_parts.append('(.+)' if j == last_kanji_idx else '(.+?)')
        else:
            # 非汉字段需要转换为平假名后做匹配（处理片假名送假名的情况）
            regex_parts.append(escape_regex(katakana_to_hiragana(seg['text'])))

    pattern = '^' + ''.join(regex_parts) + '$'
    match = re.match(pattern, hiragana_reading)

    if not match:
        # 匹配失败时回退：整词注音
        return f'{surface_form}[{hiragana_reading}]'

    # 用捕获组结果拼接: 汉字[读音] + 非汉字原样
    result = ''
    group_idx = 1
    for seg in segments:
        if seg['is_kanji']:
            result += f"{seg['text']}[{match.group(group_idx)}]"
            group_idx += 1
        else:
            result += seg['text']
    return result


# ──────────────────────────────────────────────
# Sudachi 词性映射（Sudachi 6 层 POS → Kuromoji 兼容格式）
# ──────────────────────────────────────────────

def morpheme_to_word(morpheme) -> dict:
    """
    将 SudachiPy Morpheme 转换为与 Kuromoji 输出格式兼容的 dict。
    SudachiPy POS 返回 6 层元组: (品詞, 細分類1, 細分類2, 細分類3, 活用型, 活用形)
    """
    surface = morpheme.surface()
    pos_tuple = morpheme.part_of_speech()  # 6 层元组

    # 映射到 Kuromoji 兼容字段
    pos = pos_tuple[0] if len(pos_tuple) > 0 else ''
    pos_detail_1 = pos_tuple[1] if len(pos_tuple) > 1 else '*'
    pos_detail_2 = pos_tuple[2] if len(pos_tuple) > 2 else '*'
    pos_detail_3 = pos_tuple[3] if len(pos_tuple) > 3 else '*'
    conjugated_type = pos_tuple[4] if len(pos_tuple) > 4 else '*'
    conjugated_form = pos_tuple[5] if len(pos_tuple) > 5 else '*'

    # 基本形 / 读音
    basic_form = morpheme.dictionary_form()
    reading = morpheme.reading_form()  # 片假名
    normalized_form = morpheme.normalized_form()

    # 汉字判定 + 注音生成
    has_kanji = bool(KANJI_RE.search(surface))
    furigana = ''
    ruby_text = surface

    if has_kanji and reading:
        furigana = katakana_to_hiragana(reading)
        ruby_text = generate_ruby_text(surface, reading)

    return {
        # Kuromoji 兼容字段
        'surface_form': surface,
        'pos': pos,
        'pos_detail_1': pos_detail_1,
        'pos_detail_2': pos_detail_2,
        'pos_detail_3': pos_detail_3,
        'conjugated_type': conjugated_type,
        'conjugated_form': conjugated_form,
        'basic_form': basic_form,
        'reading': reading,
        'pronunciation': reading,  # Sudachi 没有独立的 pronunciation，复用 reading
        'furigana': furigana,
        'ruby_text': ruby_text,
        # Sudachi 新增字段
        'normalized_form': normalized_form,
    }


# ──────────────────────────────────────────────
# 文章处理
# ──────────────────────────────────────────────

def process_article(article_dir: str, tokenizer, split_mode) -> bool:
    """处理单篇文章：读取 raw.json，用 Sudachi 分词，输出 processed.json"""
    raw_path = os.path.join(article_dir, 'raw.json')
    aligned_path = os.path.join(article_dir, 'aligned.json')
    processed_path = os.path.join(article_dir, 'processed.json')

    if not os.path.exists(raw_path):
        print(f'  ⏭️ 跳过 {os.path.basename(article_dir)}（无 raw.json）')
        return False

    with open(raw_path, 'r', encoding='utf-8') as f:
        raw_data = json.load(f)

    article_id = raw_data['id']

    # 读取对齐数据（可选）
    aligned_items = []
    if os.path.exists(aligned_path):
        with open(aligned_path, 'r', encoding='utf-8') as f:
            aligned_data = json.load(f)
        aligned_items = aligned_data.get('items', aligned_data.get('sentences', []))
        print(f'  🔄 处理 {article_id}: {len(raw_data["sentences"])} 句 '
              f'(有对齐数据: {len(aligned_items)} 条)')
    else:
        print(f'  🔄 处理 {article_id}: {len(raw_data["sentences"])} 句 '
              f'(无对齐数据，时间戳将为空)')

    processed_sentences = []

    for index, sentence_text in enumerate(raw_data['sentences']):
        # 移除假名注音得到纯文本
        clean_text = re.sub(r'\[.*?\]', '', sentence_text)

        # 用 Sudachi 分词
        morphemes = tokenizer.tokenize(clean_text, split_mode)
        words = [morpheme_to_word(m) for m in morphemes]

        # 从对齐数据中查找匹配的时间戳和翻译
        start_ms = None
        end_ms = None
        translation = ''

        if aligned_items:
            # 优先用 index 匹配，其次用文本内容匹配
            by_index = next((item for item in aligned_items if item.get('index') == index), None)
            by_text = next((item for item in aligned_items if
                            clean_text in re.sub(r'\[.*?\]', '',
                                                  item.get('text', item.get('clean_text', '')))
                            or re.sub(r'\[.*?\]', '',
                                      item.get('text', item.get('clean_text', ''))) in clean_text),
                           None)
            matched = by_index or by_text
            if matched:
                start_ms = matched.get('start_ms')
                end_ms = matched.get('end_ms')
                translation = matched.get('translation', '')

        processed_sentences.append({
            'original_text_with_ruby': sentence_text,
            'clean_text': clean_text,
            'translation': translation,
            'start_ms': start_ms,
            'end_ms': end_ms,
            'index': index,
            'words': words,
        })

    # 验证句子数量一致
    if len(processed_sentences) != len(raw_data['sentences']):
        print(f'  ❌ 句子数量不一致！raw: {len(raw_data["sentences"])}, '
              f'processed: {len(processed_sentences)}')
        return False

    processed_data = {
        'id': raw_data['id'],
        'title': raw_data.get('title', ''),
        'clean_title': raw_data.get('clean_title', ''),
        'time': raw_data.get('time', ''),
        'audio_uri': raw_data.get('audio_uri', ''),
        'tokenizer': 'sudachi',
        'sentences': processed_sentences,
    }

    with open(processed_path, 'w', encoding='utf-8') as f:
        json.dump(processed_data, f, ensure_ascii=False, indent=2)

    total_words = sum(len(s['words']) for s in processed_sentences)
    print(f'  ✅ → {article_id}/processed.json '
          f'({len(processed_sentences)} 句, {total_words} 词)')
    return True


# ──────────────────────────────────────────────
# 主流程
# ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='SudachiPy 分词处理（批量）')
    parser.add_argument('--mode', choices=['A', 'B', 'C'], default='B',
                        help='Sudachi 分割模式: A=最短, B=中等(默认), C=最长')
    args = parser.parse_args()

    split_mode = SPLIT_MODE_MAP[args.mode]

    print(f'🚀 Sudachi 分词处理（批量，Mode {args.mode}）')

    # 初始化 Sudachi 分词器
    dictionary = Dictionary()
    tokenizer = dictionary.create()

    # 扫描 data/ 下所有文章文件夹
    if not os.path.exists(DATA_DIR):
        print(f'❌ 数据目录不存在: {DATA_DIR}')
        sys.exit(1)

    article_dirs = sorted([
        os.path.join(DATA_DIR, name)
        for name in os.listdir(DATA_DIR)
        if os.path.isdir(os.path.join(DATA_DIR, name))
        and os.path.exists(os.path.join(DATA_DIR, name, 'raw.json'))
    ])

    print(f'📂 发现 {len(article_dirs)} 篇文章待处理\n')

    success_count = 0
    for d in article_dirs:
        if process_article(d, tokenizer, split_mode):
            success_count += 1

    print(f'\n🎉 处理完成！成功 {success_count}/{len(article_dirs)} 篇')


if __name__ == '__main__':
    main()
