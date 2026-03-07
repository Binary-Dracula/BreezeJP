import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from zhipuai import ZhipuAI
from zhipuai.core._errors import APIRequestFailedError, APIStatusError

API_KEY = "243e26744481482186691b9637ba792c.b68wDovIzyhgFd3T"
MODEL = "glm-4-flash" 

prompt_template = """你是一个专业的日语翻译与语法分析专家。请严格将以下英文语法说明翻译为准确、流畅的中文。
要求：
- 准确传达原意，符合中文母语者的日语学习习惯。
- 必须严格输出纯 JSON 格式数据，绝对不要包含任何前置说明、后置说明或 markdown 代码块标记 (如 ```json)。
- 结构必须完全符合规定，返回包含以下字段的 JSON:
{{
  "definition_cn": "中文含义翻译",
  "how_to_use_cn": "中文接续翻译",
  "context_cn": {{
    "when_to_use": "中文使用情境翻译",
    "limitations": [
      "中文限制条件翻译1",
      "中文限制条件翻译2"
    ]
  }},
  "examples_chinese": [
    "中文例句翻译1",
    "中文例句翻译2"
  ]
}}

待处理的英文数据如下：
Grammar: {grammar}
Definition EN: {definition_en}
How to Use EN: {how_to_use_en}
Context EN: {context_en}
Examples EN (in order):
{examples_en}
"""

def translate_item(client, item):
    examples_en = "\n".join([f"{i+1}. {ex.get('english', '')}" for i, ex in enumerate(item.get('examples', []))])
    
    prompt = prompt_template.format(
        grammar=item.get('grammar'),
        definition_en=item.get('definition_en', ''),
        how_to_use_en=item.get('how_to_use_en', ''),
        context_en=json.dumps(item.get('context_en', {}), ensure_ascii=False),
        examples_en=examples_en
    )
    
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
            
            if result_text.startswith("```json"): result_text = result_text[7:]
            if result_text.startswith("```"): result_text = result_text[3:]
            if result_text.endswith("```"): result_text = result_text[:-3]
            
            parsed_result = json.loads(result_text.strip())
            return parsed_result
            
        except APIStatusError as e:
            if e.status_code == 429:
                print(f"Rate limited (429). Waiting {retry_delay}s... (Attempt {attempt+1}/{max_retries})")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                print(f"API Error {e.status_code}: {e}")
                return None
        except Exception as e:
            print(f"Error translating grammar {item.get('grammar')}: {e}")
            return None

    return None

def process_single(client, item, idx, total, lock, file_path, data):
    if 'definition_cn' in item and item['definition_cn']:
        return False
        
    print(f"Translating [{idx+1}/{total}]: {item['grammar']}")
    
    parsed_zh = translate_item(client, item)
    if parsed_zh:
        item['definition_cn'] = parsed_zh.get('definition_cn', '')
        item['how_to_use_cn'] = parsed_zh.get('how_to_use_cn', '')
        
        context_zh = parsed_zh.get('context_cn', {})
        item['context_cn'] = {
            'when_to_use': context_zh.get('when_to_use', ''),
            'limitations': context_zh.get('limitations', [])
        }
        
        examples_chinese = parsed_zh.get('examples_chinese', [])
        for j, ex in enumerate(item.get('examples', [])):
            if j < len(examples_chinese):
                ex['chinese'] = examples_chinese[j]
                
        with lock:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--> Saved progress after item {item['grammar']} ({idx+1}/{total})")
            
        return True
    else:
        print(f"Failed to translate {item['grammar']}, skipping for now.")
        return False

def main():
    file_path = 'raw_grammar_data.json'
    if not os.path.exists(file_path):
        print(f"File {file_path} not found.")
        return
        
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    client = ZhipuAI(api_key=API_KEY)
    
    for item in data:
        for key in ['meaning', 'connection', 'tip']:
            item.pop(key, None)
            
    total = len(data)
    lock = Lock()
    
    max_workers = 20
    print(f"Starting concurrent translation with {max_workers} threads using {MODEL}...")
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, item in enumerate(data):
            if not ('definition_cn' in item and item['definition_cn']):
                futures.append(executor.submit(process_single, client, item, i, total, lock, file_path, data))
                
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:
                print(f"Generation generated an exception: {exc}")

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Translation process completed.")

if __name__ == "__main__":
    main()
