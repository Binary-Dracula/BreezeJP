import json
import os
import sys
from zhipuai import ZhipuAI

# 配置
# 读取系统环境变量中的 ZHIPU_API_KEY，需要用户在终端中先 export ZHIPU_API_KEY="xxx"
API_KEY = os.environ.get("243e26744481482186691b9637ba792c.b68wDovIzyhgFd3T")

prompt_template = """你是一个专业日语新闻翻译专家。请将以下日语新闻短句翻译为自然、流畅的简体中文。
要求：
1. 必须准确传达原意，但中文语序要自然，不要有明显的翻译腔。
2. 遇到专有名词（如人名、地名、机构名）请根据常见译法翻译。如果拿不准，可以保留日文汉字但在括号内加注平假名。
3. 请只输出翻译结果，不要包含任何前导语、解释或多余的标点符号。

日文输入：
{text}
"""

def translate_item(client, text):
    if not text.strip():
        return ""
    try:
        response = client.chat.completions.create(
            model="glm-4-flash", # 使用性价比较高的模型
            messages=[
                {"role": "user", "content": prompt_template.format(text=text)}
            ],
            temperature=0.1, # 降低随机性，确保翻译准确
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"翻译失败: {text} -> {e}")
        return ""

def main():
    if not API_KEY:
        print("错误：未检测到 ZHIPU_API_KEY 环境变量。请先运行 export ZHIPU_API_KEY='你的密钥'")
        sys.exit(1)

    if len(sys.argv) < 2:
        print("使用方法: python translate_json.py <输入json路径>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = input_path.replace(".json", "_translated.json")

    print(f"正在读取 {input_path} ...")
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    client = ZhipuAI(api_key=API_KEY)
    total_items = sum(len(article.get("items", [])) for article in data)
    current_idx = 0

    print(f"总计找到 {total_items} 句话待翻译。开始请求 Zhipu API...")

    for article in data:
        items = article.get("items", [])
        for item in items:
            current_idx += 1
            jap_text = item.get("text", "")
            
            # 如果已经有翻译，或者原文为空，跳过
            if item.get("translation") or not jap_text:
                continue

            # NHK原文中带有 注音的方括号，比如：国会[こっかい]で
            # 翻译时最好去掉注音，只留汉字让 AI 更好理解
            import re
            clean_jap_text = re.sub(r'\[.*?\]', '', jap_text)
            
            print(f"[{current_idx}/{total_items}] 正在翻译: {clean_jap_text[:20]}...")
            zh_trans = translate_item(client, clean_jap_text)
            
            if zh_trans:
                item["translation"] = zh_trans
                print(f"    --> {zh_trans}")

    print(f"翻译完成！正在写入 {output_path} ...")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("写入成功！")

if __name__ == "__main__":
    main()
