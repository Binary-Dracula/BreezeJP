import json
import os
import sys
import re
import time
import random
from zhipuai import ZhipuAI

# 配置
API_KEY = os.environ.get("ZHIPU_API_KEY", "")

prompt_template = """你是一个专业日语新闻翻译专家。请将以下日语新闻短句翻译为自然、流畅的简体中文。
要求：
1. 必须准确传达原意，但中文语序要自然，不要有明显的翻译腔。
2. 遇到专有名词（如人名、地名、机构名）请根据常见译法翻译。如果拿不准，可以保留日文汉字但在括号内加注平假名。
3. 请只输出翻译结果，不要包含任何前导语、解释或多余的标点符号。

日文输入：
{text}
"""

def translate_item(client, text, max_retries=3):
    if not text.strip():
        return ""
    
    for attempt in range(max_retries):
        try:
            # 基础延迟，避免瞬间高频
            time.sleep(0.5 + random.random() * 0.5) 
            
            response = client.chat.completions.create(
                model="glm-4-flash", # 使用性价比较高的模型
                messages=[
                    {"role": "user", "content": prompt_template.format(text=text)}
                ],
                temperature=0.1, # 降低随机性，确保翻译准确
            )
            return response.choices[0].message.content.strip()
        except Exception as e:
            error_str = str(e)
            if "1302" in error_str or "rate limit" in error_str.lower():
                # 速率限制错误，进行指数退避
                wait_time = (2 ** attempt) + random.random()
                print(f"    ⚠️ 触发速率限制，正在重试 ({attempt + 1}/{max_retries})，等待 {wait_time:.1f}s...")
                time.sleep(wait_time)
                continue
            
            print(f"翻译失败: {text} -> {e}")
            return ""
    return ""

def process_article(article_dir, client):
    """处理单篇文章的翻译"""
    processed_path = os.path.join(article_dir, 'processed.json')
    if not os.path.exists(processed_path):
        return False, 0
    
    with open(processed_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    sentences = data.get('sentences', [])
    if not sentences:
        return False, 0
        
    article_id = data.get('id', 'unknown')
    total = len(sentences)
    translated_count = 0
    
    # 检查是否需要翻译（全部都有 translation 的就跳过）
    needs_translation = False
    for s in sentences:
        # 如果 sentence 原文本来就为空，不翻译
        jap_text = s.get('clean_text', '') or s.get('original_text_with_ruby', '')
        if jap_text and not s.get('translation'):
            needs_translation = True
            break
            
    if not needs_translation:
        print(f"  ⏭️ {article_id}: 所有句子已有翻译，跳过")
        return True, 0
        
    print(f"  🔄 翻译 {article_id}: {total} 句")
    
    for i, s in enumerate(sentences):
        jap_text = s.get('clean_text', '') or s.get('original_text_with_ruby', '')
        if not jap_text or s.get('translation'):
            continue
            
        # 清理注音方括号，比如：国会[こっかい]で -> 国会で
        clean_jap_text = re.sub(r'\[.*?\]', '', jap_text)
        
        zh_trans = translate_item(client, clean_jap_text)
        if zh_trans:
            s['translation'] = zh_trans
            translated_count += 1
            print(f"    [{i+1}/{total}] {zh_trans}")
            
    # 只在有翻译更新时才写回文件
    if translated_count > 0:
        with open(processed_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"  ✅ -> {processed_path} (新增翻译: {translated_count} 句)")
        
    return True, translated_count

def main():
    print("🚀 中文机器翻译处理（批量）")
    if not API_KEY:
        print("⚠️ 警告：未检测到 ZHIPU_API_KEY 环境变量，跳过翻译步骤。")
        print("   如果需要翻译，请先执行: export ZHIPU_API_KEY='你的密钥'")
        sys.exit(0) # Not an error, just skip

    script_dir = os.path.dirname(os.path.abspath(__file__))
    pipeline_dir = os.path.dirname(script_dir)
    data_dir = os.path.join(pipeline_dir, "data")
    
    if not os.path.exists(data_dir):
        print(f"❌ 数据目录不存在: {data_dir}")
        sys.exit(1)
        
    article_dirs = []
    for name in sorted(os.listdir(data_dir)):
        d = os.path.join(data_dir, name)
        if os.path.isdir(d) and os.path.exists(os.path.join(d, 'processed.json')):
            article_dirs.append(d)
            
    print(f"📂 发现 {len(article_dirs)} 篇文章，准备检查并翻译\n")
    if not article_dirs:
        print("⚠️ 未找到任何文章数据")
        return

    client = ZhipuAI(api_key=API_KEY)
    
    success_articles = 0
    total_translated = 0
    
    for d in article_dirs:
        success, count = process_article(d, client)
        if success:
            success_articles += 1
            total_translated += count
            
    print(f"\n🎉 翻译处理完成！总计新增翻译句子数: {total_translated}")

if __name__ == "__main__":
    main()
