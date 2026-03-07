import json
import os
from zhipuai import ZhipuAI

API_KEY = "243e26744481482186691b9637ba792c.b68wDovIzyhgFd3T"
MODEL = "glm-4-plus"

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

def main():
    with open('raw_grammar_data.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 1. 准备 batch_input.jsonl
    jsonl_path = "batch_input.jsonl"
    with open(jsonl_path, 'w', encoding='utf-8') as f:
        for i, item in enumerate(data):
            if 'definition_cn' in item and item['definition_cn']:
                continue
                
            examples_en = "\n".join([f"{j+1}. {ex.get('english', '')}" for j, ex in enumerate(item.get('examples', []))])
            prompt = prompt_template.format(
                grammar=item.get('grammar'),
                definition_en=item.get('definition_en', ''),
                how_to_use_en=item.get('how_to_use_en', ''),
                context_en=json.dumps(item.get('context_en', {}), ensure_ascii=False),
                examples_en=examples_en
            )
            
            req = {
                "custom_id": f"row-{i}",
                "method": "POST",
                "url": "/v4/chat/completions",
                "body": {
                    "model": MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.1
                }
            }
            f.write(json.dumps(req, ensure_ascii=False) + "\n")

    print(f"Created {jsonl_path}")

    # 2. 上传文件并启动 Batch
    client = ZhipuAI(api_key=API_KEY)
    
    print("Uploading file to Zhipu...")
    result = client.files.create(file=open(jsonl_path, "rb"), purpose="batch")
    file_id = result.id
    print(f"File uploaded. File ID: {file_id}")
    
    print("Creating batch...")
    batch = client.batches.create(
        input_file_id=file_id,
        endpoint="/v1/chat/completions",
        completion_window="24h"
    )
    print(f"Batch created successfully!")
    print(f"Batch ID: {batch.id}")
    print(f"Status: {batch.status}")

if __name__ == "__main__":
    main()
