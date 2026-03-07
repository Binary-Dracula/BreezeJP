import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from openai import OpenAI
import httpx

# 用户需要在此处或环境变量中提供您的阿里云 DashScope API Key
API_KEY = os.environ.get("DASHSCOPE_API_KEY", "sk-1c58f56dd07746c390bdc580d9a1efba") 
# 用户指定了 qwen3.5-plus，但在 DashScope API 中，千问 Plus 的标准调用名称通常为 qwen-plus 
MODEL = "qwen-plus" 

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
            
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "rate limit" in err_str.lower():
                print(f"Rate limited (429). Waiting {retry_delay}s...")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                return None

    return None

def process_single(client, item, idx, total, lock, file_path, data):
    examples = item.get('examples', [])
    updated = False
    
    for ex in examples:
        # We will override the ones from the previous generator by checking for a different key, 
        # but the prompt says they want to overwrite or replace `japanese_ruby`
        # Let's forcefully overwrite the japanese_ruby field for the sake of trying qwen
        ruby_text = generate_ruby(client, ex.get('japanese', ''))
        if ruby_text:
            ex['japanese_ruby'] = ruby_text
            updated = True
        else:
            print(f"Failed to generate ruby for: {ex.get('japanese', '')}")
                
    if updated:
        with lock:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--> Saved ruby progress (Qwen) after item {item['grammar']} ({idx+1}/{total})")
        return True
    return False

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    if API_KEY == "在此处填入您的API_KEY":
        print("请先配置 DASHSCOPE_API_KEY 环境变量或直接在文件中填入 API KEY。")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    # Using DashScope's OpenAI compatible endpoint
    client = OpenAI(
        api_key=API_KEY,
        base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
        http_client=httpx.Client(limits=httpx.Limits(max_connections=100, max_keepalive_connections=20))
    )
    
    total = len(data)
    lock = Lock()
    
    print(f"Starting concurrent ruby generation using Qwen ({MODEL}) for 5 grammar items for testing...")
    
    max_workers = 5 
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, item in enumerate(data[:5]):
            futures.append(executor.submit(process_single, client, item, i, 5, lock, file_path, data))
                
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:
                print(f"Exception: {exc}")

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Qwen Ruby generation process completed.")

if __name__ == "__main__":
    main()
