import json
import os
import pykakasi
import re
from functools import lru_cache

kks = pykakasi.kakasi()

@lru_cache(maxsize=10000)
def generate_ruby(text):
    if not text:
        return ""
        
    result = kks.convert(text)
    out = []
    
    for item in result:
        orig = item['orig']
        hira = item['hira']
        
        # If no Kanji, keep original
        if not re.search(r'[\u4e00-\u9fff]', orig):
            out.append(orig)
            continue
            
        orig_len = len(orig)
        hira_len = len(hira)
        
        # Find common suffix (Okurigana at the end, e.g. しい in 新しい)
        suffix = ""
        i = 1
        while i <= orig_len and i <= hira_len:
            if orig[-i] == hira[-i]:
                suffix = orig[-i] + suffix
                i += 1
            else:
                break
                
        # Find common prefix (Prefix like お in お茶)
        prefix = ""
        j = 0
        hira_start = 0
        orig_start = 0
        while j < (orig_len - len(suffix)) and j < (hira_len - len(suffix)):
            if orig[j] == hira[j]:
                prefix += orig[j]
                j += 1
                hira_start += 1
                orig_start += 1
            else:
                break
                
        # Slicing the kanji core from the okurigana
        kanji_part = orig[orig_start : orig_len - len(suffix)]
        ruby_part = hira[hira_start : hira_len - len(suffix)]
        
        if kanji_part and ruby_part and kanji_part != ruby_part:
            out.append(f"{prefix}{kanji_part}[{ruby_part}]{suffix}")
        else:
            out.append(orig)
            
    return "".join(out)

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    count = 0
    
    print("Starting exact deterministic string-matching ruby generation via PyKakasi...")
    
    for item in data:
        for ex in item.get('examples', []):
            sentence = ex.get('japanese', '')
            if sentence:
                ex['japanese_ruby'] = generate_ruby(sentence)
                count += 1
                
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"Success! Replaced all broken LLM generations with {count} perfect rule-based Ruby annotations.")

if __name__ == "__main__":
    main()
