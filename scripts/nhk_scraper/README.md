# NHK Easy News 爬虫与音频提取工具

这个工具集用于从 NHK NEWS WEB EASY 获取新闻的带注音文本和朗读录音。
由于 NHK 最近升级了 Akamai 防护机制（引入了 JWT 和动态签名的 M3U8流），全自动爬虫很容易被 `401/403` 拦截。因此，目前的脚本设计为**半自动模式**（浏览器抓取 Token + 脚本处理）。

## 包含文件

- `nhk_scraper.py`: 用于提取新闻正文（将 HTML 的 `<ruby>` 转换为 `漢字[かんじ]` 格式），需要提供 `z_at` Token 获取 JSON 列表和正文授权。
- `download_audio.py`: 用于强制下载带时间戳签名的 HLS (`.m3u8`) 音频流并转换为 `.mp3` 格式。
- `test_output.json`: 已成功抓取的 5 篇测试数据，可直接用于 App 开发。
- `output/`: 存放按 `news_id` 划分的音频 mp3 文件和对应 JSON 的目录。

## 如何在未来采集更多数据？

### 第一步：获取新闻列表与正文 (nhk_scraper.py)

1. **获取 Token**:
   - 在普通浏览器中打开 `https://news.web.nhk/news/easy/`。
   - 打开浏览器的“开发者工具” (F12) -> Network (网络) 面板。
   - 过滤 `news-list.json`。
   - 在 Request Headers（请求头）或 Cookies 中找到 `z_at` 的值（这是一串很长的 JWT 字符串）。
2. **填入脚本**:
   - 打开 `nhk_scraper.py`，将 `Z_AT_TOKEN` 变量替换为你刚获取的值。
3. **运行脚本**:
   - `python nhk_scraper.py`
   - 脚本会在 `output/` 目录下生成各个新闻 ID 的 `article.json`。

### 第二步：下载受保护的音频 (download_audio.py)

1. **捕获音频链接**:
   - 在浏览器中点击任意新闻页面的 “ニュースを聞く (Listen to the news)” 按钮。
   - 在 Network 面板中寻找 `index.m3u8?hdnts=...` 这样的请求。
   - **重点**：这个 `hdnts` 参数是临时的播放授权签名。你可以把包含该签名的完整 URL 复制出来。
2. **填入脚本**:
   - 打开 `download_audio.py`，将抓取到的带 Token 的完整 M3U8 URL 添加到 `VALID_M3U8_URLS` 字典中，键为对应的 `news_id`。
   - 同一个 session 获取到的 `hdnts` 签名通常在几分钟内对多篇文章的音频都有效。
3. **运行脚本**:
   - `python download_audio.py`
   - 脚本会调用 `ffmpeg` 下载这些流媒体并合并为常规的 `.mp3` 文件。

## 注意事项

* 请确保电脑上安装了 `ffmpeg`（Mac 上可使用 `brew install ffmpeg`）。
* 如果你未来希望做成全自动的定期爬虫，建议使用 Playwright 或 Selenium 定期打开无头浏览器获取这些 Token 后再交由脚本处理。
