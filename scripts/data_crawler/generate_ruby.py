import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from zhipuai import ZhipuAI
from zhipuai.core._errors import APIStatusError

API_KEY = "243e26744481482186691b9637ba792c.b68wDovIzyhgFd3T"
MODEL = "glm-4-flash" 

prompt_template = """你是一个专业的日语分析专家。请将给出的日文句子转化为带 Ruby Furigana 注音的纯净格式。
要求：
- 格式规则必须是：**仅对日语汉字部分加注音**，使用 `汉字[注音]` 的形式标注。
- 绝对不要对纯平假名、纯片假名加注音（没有汉字就不加括号）。
- **非常关键的送假名（Okurigana）规则**：如果一个汉字词带有送假名，注音括号**必须且只能**包裹在汉字本身的后面！送假名必须保留在括号外部。
  - 正确示例：`新[あたら]しい`、`食[た]べる`、`漢字[かんじ]`、`私[わたし]`
  - 错误示例：`新しい[あたらしい]`（绝对禁止）、`食べる[たべる]`（绝对禁止）
- 只有日文句子，不要任何开头、结尾和 markdown 代码块（如 ```）。
- 务必保证翻译准确且完全符合日语发音字典。

原句：
{sentence}

输出：
"""

def generate_ruby(client, sentence):
    prompt = prompt_template.format(sentence=sentence)
    
    max_retries = 3
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1
            )
            result_text = response.choices[0].message.content.strip()
            
            # Clean up potential markdown formatting
            if result_text.startswith("```"):
                lines = result_text.split('\n')
                if len(lines) > 2:
                    result_text = '\n'.join(lines[1:-1])
            
            return result_text.strip()
            
        except APIStatusError as e:
            if e.status_code == 429:
                print(f"Rate limited (429). Waiting {retry_delay}s...")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                return None
        except Exception as e:
            return None

    return None

def process_single(client, item, idx, total, lock, file_path, data):
    examples = item.get('examples', [])
    updated = False
    
    for ex in examples:
        if 'japanese_ruby' not in ex:
            sentence = ex.get('japanese', '')
            if not sentence:
                continue
                
            ruby_text = generate_ruby(client, sentence)
            if ruby_text:
                ex['japanese_ruby'] = ruby_text
                updated = True
            else:
                print(f"Failed to generate ruby for: {sentence}")
                
    if updated:
        with lock:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--> Saved ruby progress after item {item['grammar']} ({idx+1}/{total})")
        return True
    return False

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    client = ZhipuAI(api_key=API_KEY)
    total = len(data)
    lock = Lock()
    
    # Check if we need to run
    items_to_process = [item for item in data if any('japanese_ruby' not in ex for ex in item.get('examples', []))]
    
    if not items_to_process:
        print("All Japanese sentences already have ruby annotations.")
        return
        
    print(f"Starting concurrent ruby generation for {len(items_to_process)} grammar items...")
    
    max_workers = 20
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, item in enumerate(data):
            if any('japanese_ruby' not in ex for ex in item.get('examples', [])):
                 futures.append(executor.submit(process_single, client, item, i, total, lock, file_path, data))
                
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:
                print(f"Exception: {exc}")

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Ruby generation process completed.")

if __name__ == "__main__":
    main()
