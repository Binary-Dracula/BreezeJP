---
description: How to run the NHK Easy News data scraping and alignment pipeline
---

# NHK Easy News Pipeline Process

NHK Easy News 的数据抓取流程需要从浏览器获取 `z_at` JWT Token，因为 API 和媒体端点受 Akamai WAF 保护。

> [!IMPORTANT]
> **DNS 前置条件**：NHK 的 CDN 域名 `media.vd.st.nhk` 和 `mediatoken.web.nhk` 在中国大陆的 DNS 无法解析。
> 首次使用前需要通过浏览器的 DNS-over-HTTPS 查询这两个域名的 IP 并写入 `/etc/hosts`：
> ```bash
> echo "23.200.3.236 media.vd.st.nhk" | sudo tee -a /etc/hosts
> echo "184.26.43.72 mediatoken.web.nhk" | sudo tee -a /etc/hosts
> ```
> IP 地址可能因 CDN 节点变动而失效，如遇到连接问题需重新查询更新。

当用户要求抓取或更新 NHK Easy 新闻数据时，严格按以下步骤执行：

## 步骤 1: 获取 z_at Token

> [!IMPORTANT]
> **严禁**：不要要求用户手动获取 Token，也不要尝试自己用代码请求，必须单单使用 `browser_subagent`。

- 使用 `browser_subagent` 工具
- Task Prompt: "Navigate to `https://news.web.nhk/news/easy/`. Open the network tab or use document.cookie in javascript to extract the value of the `z_at` cookie. Return ONLY the exact JWT string value of the `z_at` cookie. Do not return anything else."

## 步骤 2: 更新爬虫脚本

- 用 `multi_replace_file_content` 更新 `tools/nhk_data_pipeline/scripts/nhk_scraper.py` 顶部的 `Z_AT_TOKEN` 变量

## 步骤 3: 获取 hdnts 音频 Token

> [!IMPORTANT]
> `mediatoken.web.nhk` 域名在 Python/curl 环境下可能无法解析。必须通过浏览器获取 `hdnts` Token。

> [!WARNING]
> **严禁以下行为**：
> 1. 绝对不要尝试自己编写 Python/Node.js 脚本去解析 m3u8 或下载 mp3 音频！NHK 有防盗链和分片机制，你的脚本会失败。所有的音频下载必须交给下文步骤 4 的现成管道脚本统一处理。
> 2. 不要自行拼接或臆造 mp3 URL。

- 使用 `browser_subagent` 工具
- Task Prompt: "Navigate to any NHK Easy News article page. Click the '聞く' (listen) button to start audio playback. Wait 3 seconds for the audio stream to start loading. Open the network tab and monitor network requests for URLs containing `hdnts=` or requests to `mediatoken.web.nhk` (or use executing javascript to capture XHR/fetch requests or monitor media source urls). You are looking for a string matching the pattern `exp=...~acl=...~hmac=...`. Return ONLY the complete hdnts token string. Do not include quotes or surrounding text."

## 步骤 4: 一键执行管道

如果需要机器翻译日语新闻，请先在终端配置智谱大模型 API Key（可选）：
```bash
export ZHIPU_API_KEY="你的_API_KEY"
```

> [!WARNING]
> 执行脚本时，必须严格使用以下命令格式，特别是 `--hdnts` 后面的 token **必须用双引号 `""` 包裹**，否则 bash 会因为包含 `~` 或 `=` 等特殊字符而报错。绝对不要试图自行编写任何其他的抓取或下载逻辑。

```bash
# Cwd: tools/nhk_data_pipeline
bash scripts/run_pipeline.sh --hdnts "<hdnts_token>"
```

该脚本自动串联执行以下全部步骤：
1. **爬虫**：抓取文本 + 下载音频 → `data/{id}/raw.json` + `data/{id}/{id}.mp3`
2. **音频对齐**：faster-whisper + Needleman-Wunsch → `data/{id}/aligned.json`（生成 `start_ms` / `end_ms`）
3. **Sudachi 分词**：合并对齐数据 + 分词 → `data/{id}/processed.json`（默认使用 Mode B）
4. **机器翻译** (可选)：调用 ZhipuAI 翻译每一句 → 更新进 `data/{id}/processed.json`
5. **部署到 App**：增量合并更新至 `assets/mock/test_output.json`（新抓取的新闻会自动追加，原有的保留，按时间降序排列） + 复制 mp3

脚本结束后会自动进行数据完整性检查。

## 步骤 5: 通知用户

告知用户数据已下载、对齐、翻译、处理并注入 App 的 mock 数据文件。

---

## 数据结构参考

### 目录结构

```
data/{article_id}/
├── raw.json            ← 爬虫原始数据（以句子为单位）
├── {article_id}.mp3    ← 音频文件
├── aligned.json        ← 音频对齐数据（由 align.py 生成）
└── processed.json      ← Sudachi 处理后的最终数据
```

### raw.json 格式

```json
{
  "id": "ne2026022011579",
  "title": "高市[たかいち]総理大臣[そうりだいじん]　これからどんな政治[せいじ]をするか考[かんが]え方[かた]を話[はな]した",
  "clean_title": "高市総理大臣　これからどんな政治をするか考え方を話した",
  "time": "2026-02-20T15:30:00+09:00",
  "audio_uri": "output/ne2026022011579/ne2026022011579.mp3",
  "sentences": [
    "高市[たかいち]総理大臣[そうりだいじん]が、これからどんな政治[せいじ]をするか、国会[こっかい]で政府[せいふ]の考[かんが]え方[かた]を話[はな]しました。",
    "経済[けいざい]については、日本[にっぽん]の会社[かいしゃ]への投資[とうし]が増[ふ]えるようにしたいと言[い]いました。"
  ]
}
```

- `sentences`: 按句号（。）拆分的句子数组，每句带 `[假名]` 注音
- `clean_title`: 网页原始纯净标题（不含假名注音）
- `time`: 文章发布时间，从 NHK API 的 `news_prearranged_time` 获取

### processed.json 格式

```json
{
  "id": "ne2026022011579",
  "title": "高市[たかいち]総理大臣[そうりだいじん]　これからどんな政治[せいじ]をするか考[かんが]え方[かた]を话[はな]した",
  "clean_title": "高市総理大臣　これからどんな政治をするか考え方を話した",
  "time": "2026-02-20T15:30:00+09:00",
  "audio_uri": "output/ne2026022011579/ne2026022011579.mp3",
  "tokenizer": "sudachi",
  "sentences": [
    {
      "original_text_with_ruby": "高市[たかいち]総理大臣[そうりだいじん]　これからどんな政治[せいじ]をするか考[かんが]え方[かた]を话[はな]した",
      "clean_text": "高市総理大臣　これからどんな政治をするか考え方を話した",
      "translation": "",
      "start_ms": 859,
      "end_ms": 8180,
      "index": 0,
      "words": [
        {
          "surface_form": "高市",
          "pos": "名詞",
          "pos_detail_1": "固有名詞",
          "pos_detail_2": "人名",
          "pos_detail_3": "姓",
          "conjugated_type": "*",
          "conjugated_form": "*",
          "basic_form": "高市",
          "reading": "タカイチ",
          "pronunciation": "タカイチ",
          "furigana": "たかいち",
          "ruby_text": "高市[たかいち]",
          "normalized_form": "高市"
        }
      ]
    }
  ]
}
```

- `sentences` 数量与 `raw.json` **严格一致**
- `start_ms` / `end_ms`: 来自 `aligned.json`（无对齐数据时为 null）
- `words`: Sudachi 分词结果，含 `ruby_text` 注音格式及 `normalized_form`