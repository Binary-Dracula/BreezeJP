import json
import os
import sys
from zhipuai import ZhipuAI

API_KEY = "243e26744481482186691b9637ba792c.b68wDovIzyhgFd3T"

# 尝试使用 glm-4.6v 或者根据实际可用的模型退回
MODEL = "glm-4.6v" 
client = ZhipuAI(api_key=API_KEY)

prompt_template = """你是一个专业的日语语法专家。请读取以下英文结构，将其提炼、翻译为符合中文日语学习者习惯的三要素：
1. meaning (含义): 将 "definition_en" 分析为最核心的短句，如“用于表示存在或判断。相当于中文的‘是’”。
2. connection (接续): 将 "how_to_use_en" 转化为接续公式并加上说明。如果是名词/形动词，可以用"名词/ナ形容词 + だ/です"。
3. tip (提示): 将 "context_en" 里的 when_to_use 和 limitations 综合提炼为几条重点中文提示。

同时，请把以下所有 "examples" 中的英文句子翻译成对应的中文。
请输出最纯粹的 JSON 格式（不要使用 ```json 标记包裹，不要带多余字符），结构严格符合如下格式：
{{
  "meaning": "中文含义",
  "connection": "中文接续",
  "tip": "中文提示",
  "examples_chinese": [
    "中文例句1",
    "中文例句2",
    ...
  ]
}}

待处理内容：
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
        
    target_item = None
    target_idx = -1
    for i, item in enumerate(data):
        if item.get('grammar') == 'です':
            target_item = item
            target_idx = i
            break
            
    if not target_item:
        print("未找到 'です'")
        return
        
    examples_en = "\n".join([f"{i+1}. {ex['english']}" for i, ex in enumerate(target_item.get('examples', []))])
    
    prompt = prompt_template.format(
        grammar=target_item.get('grammar'),
        definition_en=target_item.get('definition_en', ''),
        how_to_use_en=target_item.get('how_to_use_en', ''),
        context_en=json.dumps(target_item.get('context_en', {}), ensure_ascii=False),
        examples_en=examples_en
    )
    
    print("Calling Zhipu API...")
    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1
        )
        result_text = response.choices[0].message.content.strip()
        
        # 去除可能包含的 markdown 标记
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        if result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
            
        parsed_result = json.loads(result_text.strip())
        
        # 将解析的内容加入到原项中
        target_item['meaning'] = parsed_result.get('meaning', '')
        target_item['connection'] = parsed_result.get('connection', '')
        target_item['tip'] = parsed_result.get('tip', '')
        
        examples_chinese = parsed_result.get('examples_chinese', [])
        for i, ex in enumerate(target_item.get('examples', [])):
            if i < len(examples_chinese):
                ex['chinese'] = examples_chinese[i]
                
        # 保存回原文件，确保只修改了 "です" 这一个项目
        data[target_idx] = target_item
        with open('raw_grammar_data.json', 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            
        print("\n更新后的 'です' 数据：")
        print(json.dumps(target_item, ensure_ascii=False, indent=2))
        
    except Exception as e:
        print(f"Error calling API: {e}")

if __name__ == "__main__":
    main()
