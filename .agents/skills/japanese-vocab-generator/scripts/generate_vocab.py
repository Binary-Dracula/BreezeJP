"""
日语单词 JSON 数据批量生成器
==============================
通过 Gemini API 批量生成结构化的日语单词学习数据（9 大维度），
输出为 JSON 数组，供 BreezeJP App 使用。

用法:
    python generate_vocab.py --input files/单词生成器/单词源/n3_verbs.txt

    输入文件格式（纯文本，单词以英文逗号分隔）：
        間に合う,適当,妥協,把握,皮肉

    输出文件自动保存至 files/单词生成器/输出结果/，
    文件名 = 输入文件名（不含扩展名）+ 毫秒时间戳 + .json
    例如：n3_verbs_1743000000000.json

免费层配额限制（Gemini API）:
    - RPM (请求/分钟): 15  ← 脚本批大小=3，间隔=5.5秒，约11 RPM
    - TPM (Token/分钟): 250K  ← 每个请求≈8000 tokens，安全范围内
    - RPD (请求/天): 500  ← 500请求 × 3词/批 ≈ 1500词/天上限

警告：如输入超过 1450 个单词，需要跨多天处理！

环境变量:
    GEMINI_API_KEY  — 必须设置。Gemini API 密钥。
                      获取方式: https://aistudio.google.com/apikey
                      设置方式 (在 ~/.zshrc 或 ~/.bash_profile 中添加):
                          export GEMINI_API_KEY="你的API密钥"
                      或在运行前临时设置:
                          GEMINI_API_KEY="你的API密钥" python generate_vocab.py --input ...
"""

from google import genai
from google.genai import types
import argparse
import json
import os
import sys
import time
from pathlib import Path

# ──────────────────────────────────────────────
# 1. API Key — 从环境变量 GEMINI_API_KEY 读取
# ──────────────────────────────────────────────
# 如需更换 API Key，修改环境变量即可，不要在代码中硬编码。
# 在终端执行:  export GEMINI_API_KEY="新的密钥"
# 或写入 ~/.zshrc 永久生效:  echo 'export GEMINI_API_KEY="新的密钥"' >> ~/.zshrc
API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    print("❌ 错误：未设置环境变量 GEMINI_API_KEY")
    print("   请先执行: export GEMINI_API_KEY=\"你的Gemini API密钥\"")
    print("   获取密钥: https://aistudio.google.com/apikey")
    sys.exit(1)

client = genai.Client(api_key=API_KEY)

# ──────────────────────────────────────────────
# 2. System Prompt — 定义输出格式与质量要求
# ──────────────────────────────────────────────
SYSTEM_PROMPT = """
你现在是一位精通中日双语的资深日语教育专家。
请根据我提供的日语单词列表，严格按照以下 JSON 数组的格式输出所有信息。

【严格格式要求】
1. 所有的日文汉字（包括例句、释义、解释说明中的日文）**必须标注假名**。
2. 假名只表示日文汉字部分。
3. 连续的日文汉字，ruby写在一起。
4. 假名必须使用 [ruby] 的格式，例如：`一生懸命[いっしょうけんめい]`，或者动词 `気[き]づく`。
5. **【重要】关于结构 2 到 9：这些部分通常包含多个维度。如果该单词有多个释义、多种助词搭配、多个构词汉字、多个近/反义词、多个高频搭配或多个易错点，请务必在各自的数组（列表）中全部列出，不要只列一项！**

【输出格式】
必须输出一个 JSON 数组 (Array)，数组中的每个对象代表一个单词,
请严格按照以下 JSON 格式输出（如果该单词是名词，请自行省略或简化变形部分；如果是动词/形容词，请务必详细）
结构如下：
[
  {
"1_basic_info": {
"word": "目标单词",
"reading": "假名读音",
"romaji": "罗马音",
"pitch_accent": "声调（标明数字与类型，如：0 平板型）",
"jlpt_level": "JLPT等级",
"part_of_speech": "词性（如：五段动词，na形容词，名词等）",
"transitivity": "如果是动词，务必标明自他动词属性（自动词/他动词）；其他词性填 null"
},

"2_meanings_and_nuance": [
{
"definition": "中文释义1",
"nuance": "语感与使用场景说明（请详细解释这个词背后的深层含义，以及在什么具体场景下使用，带有什么样的感情色彩）"
},
{
"definition": "中文释义2（如果有多个意思，务必继续添加）",
"nuance": "对应的语感与使用场景说明"
}
],

"3_critical_grammar_rules": {
"associated_particles": [
{
"pattern": "该单词必须或最常搭配的助词公式1（例如：～に気づく）",
"explanation": "为什么用这个助词？绝不能用什么助词？"
},
{
"pattern": "该单词必须或最常搭配的助词公式2（如果有，务必列出全部）",
"explanation": "对应的解释"
}
]
},

"4_conjugations": {
"dictionary_form": "基本形",
"masu_form": "ます形 (肯定)",
"nai_form": "ない形 (否定)",
"te_form": "て形",
"ta_form": "た形 (过去式)",
"potential_form": "可能形 (如果是动词)",
"passive_form": "受身形 (被动)",
"causative_form": "使役形"
},

"5_kanji_components": [
{
"kanji": "拆解的单个汉字1",
"onyomi": "音读",
"kunyomi": "训读",
"meaning": "该汉字的核心本意"
},
{
"kanji": "拆解的单个汉字2（如果有多个汉字，务必全部拆解列出）",
"onyomi": "音读",
"kunyomi": "训读",
"meaning": "该汉字的核心本意"
}
],

"6_example_sentences": [
{
"level": "Casual (口語[こうご])",
"japanese": "包含目标单词的生活口语例句",
"chinese": "中文翻译"
},
{
"level": "Polite (丁寧語[ていねいご])",
"japanese": "包含目标单词的礼貌体(ます/です)例句",
"chinese": "中文翻译"
},
{
"level": "Business/Honorific (敬語[けいご])",
"japanese": "包含目标单词的职场或敬语例句",
"chinese": "中文翻译"
}
],

"7_synonyms_and_antonyms": {
"synonyms": [
{
"word": "近义词1",
"meaning": "中文释义",
"difference": "与目标单词在语感或用法上的微妙区别（非常重要）"
},
{
"word": "近义词2（如果有多个，务必全部列出）",
"meaning": "中文释义",
"difference": "区别说明"
}
],
"antonyms": [
{
"word": "反义词1",
"meaning": "中文释义"
},
{
"word": "反义词2（如果有多个，务必全部列出）",
"meaning": "中文释义"
}
]
},

"8_collocations_and_phrases": [
{
"phrase": "目标单词的高频固定搭配1",
"meaning": "中文释义"
},
{
"phrase": "目标单词的高频固定搭配2",
"meaning": "中文释义"
},
{
"phrase": "目标单词的高频固定搭配3（如果有更多，务必尽可能多列出常用的）",
"meaning": "中文释义"
}
],

"9_common_mistakes_and_usage_notes": [
{
"mistake_type": "母语为中文的学习者常犯的错误（如：受中文影响用错助词等）或同音词混淆 1",
"explanation": "详细的避坑解释"
},
{
"mistake_type": "常犯错误或注意事项 2（如果有多个坑，务必全部列出）",
"explanation": "详细的避坑解释"
}
]
}
]
(具体的内部结构要求与之前完全一致，务必详尽)
"""

# ──────────────────────────────────────────────
# 3. 生成配置与速率限制
# ──────────────────────────────────────────────
# temperature=0.2 — 低温度保证词典输出严谨，不胡编乱造
# 如需更换模型，修改 MODEL_NAME 即可
GENERATE_CONFIG = types.GenerateContentConfig(
    system_instruction=SYSTEM_PROMPT,
    response_mime_type="application/json",
    temperature=0.2,
)
MODEL_NAME = "gemini-3.1-flash-lite-preview"

# 免费层限制参数
FREE_TIER_LIMITS = {
    "rpm": 15,        # Requests Per Minute
    "tpm": 250_000,   # Tokens Per Minute
    "rpd": 500,       # Requests Per Day (最关键的限制)
}
BATCH_SIZE = 3  # 每批 3 个单词（token 成本更低，更安全）
WAIT_BETWEEN_REQUESTS = 5.5  # 秒（60 / (15-1) ≈ 4.3，取 5.5 确保安全）

# ──────────────────────────────────────────────
# 4. 命令行参数
# ──────────────────────────────────────────────
parser = argparse.ArgumentParser(description="日语单词 JSON 数据生成器")
parser.add_argument(
    "--input",
    required=True,
    help="单词源文件路径（相对于项目根目录或绝对路径），"
         "文件内容为英文逗号分隔的日语单词列表",
)
args = parser.parse_args()

# 支持相对路径（相对于项目根目录）和绝对路径
project_root = Path(__file__).resolve().parent.parent.parent.parent
input_path = Path(args.input)
if not input_path.is_absolute():
    input_path = project_root / input_path

if not input_path.exists():
    print(f"❌ 错误：找不到输入文件 {input_path}")
    sys.exit(1)

# 读取单词列表（逗号分隔，支持换行）
raw_content = input_path.read_text(encoding="utf-8")
word_list = [w.strip() for w in raw_content.replace("\n", ",").split(",") if w.strip()]
if not word_list:
    print("❌ 错误：输入文件为空或不包含任何有效单词")
    sys.exit(1)

print(f"📖 已从 {input_path.name} 读取 {len(word_list)} 个单词")

# ──────────────────────────────────────────────
# 5. 速率限制预检查
# ──────────────────────────────────────────────
requests_needed = (len(word_list) + BATCH_SIZE - 1) // BATCH_SIZE
max_words_per_day = FREE_TIER_LIMITS["rpd"] * BATCH_SIZE

print(f"\n【配额分析】")
print(f"  所需请求数: {requests_needed} (RPM 限制: {FREE_TIER_LIMITS['rpm']})")
print(f"  处理时长: ~{requests_needed * WAIT_BETWEEN_REQUESTS / 60:.1f} 分钟")
print(f"  预估 Token: ~{requests_needed * 8_250:,} (TPM 限制: {FREE_TIER_LIMITS['tpm']:,})")

if requests_needed > FREE_TIER_LIMITS["rpd"]:
    print(f"\n⚠️  警告：所需请求数 ({requests_needed}) 超过每日限制 ({FREE_TIER_LIMITS['rpd']})")
    print(f"   建议分成多个文件，每个文件最多 {max_words_per_day} 个单词")
    sys.exit(1)

if len(word_list) > max_words_per_day * 0.9:
    print(f"\n⚠️  提示：今日剩余额度可能不足，建议拆分处理")

print(f"\n开始处理，总计单词数: {len(word_list)}...\n")

# ──────────────────────────────────────────────
# 6. 批量处理
# ──────────────────────────────────────────────
all_results = []

for i in range(0, len(word_list), BATCH_SIZE):
    batch_words = word_list[i : i + BATCH_SIZE]
    prompt = f"请解析以下单词列表：{', '.join(batch_words)}"

    print(f"正在处理第 {i + 1} 到 {i + len(batch_words)} 个单词: {batch_words}")

    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
                config=GENERATE_CONFIG,
            )
            batch_result = json.loads(response.text)
            all_results.extend(batch_result)
            print("✅ 本批次处理成功！")
            break
        except Exception as e:
            print(f"❌ 出现错误: {e}")
            if attempt < max_retries - 1:
                print(f"等待 5 秒后进行第 {attempt + 2} 次重试...")
                time.sleep(5)
            else:
                print("⚠️ 本批次彻底失败，跳过。")

    # 控制请求频率，保持在 RPM 限制以内
    # 计算：60s / (RPM-1) ≈ 60 / 14 ≈ 4.3s，取 5.5s 确保安全
    time.sleep(WAIT_BETWEEN_REQUESTS)

# ──────────────────────────────────────────────
# 7. 输出结果
# ──────────────────────────────────────────────
# 输出目录：files/单词生成器/输出结果/
# 文件名 = 输入文件名（不含扩展名）+ 毫秒时间戳，避免覆盖同名文件
output_dir = project_root / "files" / "单词生成器" / "输出结果"
output_dir.mkdir(parents=True, exist_ok=True)
timestamp_ms = int(time.time() * 1000)
output_filename = output_dir / f"{input_path.stem}_{timestamp_ms}.json"

with open(output_filename, "w", encoding="utf-8") as f:
    json.dump(all_results, f, ensure_ascii=False, indent=2)

print(f"\n🎉 全部处理完成！")
print(f"   输出文件: {output_filename}")
print(f"   已保存词条数: {len(all_results)}")
print(f"\n【本次消耗】")
print(f"   请求数: {requests_needed} / {FREE_TIER_LIMITS['rpd']} (日限额)")
print(f"   Time: ~{requests_needed * WAIT_BETWEEN_REQUESTS / 60:.1f} 分钟")
