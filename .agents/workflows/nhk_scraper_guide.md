---
description: How to run the NHK Easy News data scraping and alignment pipeline
---

# NHK Easy News Pipeline Process

The NHK Easy News scraping process requires fetching a fresh `z_at` JWT token from the browser because the API and media endpoints are protected by an Akamai WAF. 

When the user asks you to scrape or update NHK Easy news data, follow these steps exactly without prompting them for tokens:

1. **Extract Token via Browser Subagent**:
   - **Do not ask the user to manually grab the token.** 
   - Use the `browser_subagent` tool.
   - Task Prompt: "Navigate to `https://news.web.nhk/news/easy/` (or `https://www3.nhk.or.jp/news/easy/`). Open the network tab or run javascript to extract the value of the `z_at` cookie. Return the exact JWT string value of the `z_at` cookie."

2. **Update the Scraper Script**:
   - Update the `Z_AT_TOKEN` variable near the top of `tools/nhk_data_pipeline/nhk_scraper.py` with the extracted JWT token using `multi_replace_file_content`.

3. **Run the Scraper**:
   - Execute: `source venv/bin/activate && python nhk_scraper.py` (Cwd: `tools/nhk_data_pipeline`).
   - The scraper handles the rest automatically:
     - Uses `curl` inside subprocesses to bypass the WAF 403 Forbidden checks that block Python `requests`.
     - Calls `https://mediatoken.web.nhk/v1/token` with the JWT in the `Authorization: Bearer <JWT>` header to obtain the Akamai `hdnts` playback token.
     - Fetches and parses the HTML to get ruby/furigana characters.
     - Uses `ffmpeg` to download the protected `.m3u8` audio streams and outputs them as `.mp3` files in the `output/` directory.
     - Saves the collected article references to `test_output.json`.

4. **Run the Audio Alignment**:
   - Execute: `source venv/bin/activate && python align.py test_output.json` (Cwd: `tools/nhk_data_pipeline`).
   - This employs `faster-whisper` to analyze the audio and generate word-level timestamps, then uses Needleman-Wunsch Dynamic Programming to strictly align these timestamps back perfectly against NHK's provided punctuation text.
   - It outputs the final app-ready data to `test_output_aligned.json`.

5. **Deploy to App Assets**:
   - Copy the newly generated aligned JSON: `cp tools/nhk_data_pipeline/test_output_aligned.json assets/mock/test_output.json`
   - Copy the newly generated audio: `cp tools/nhk_data_pipeline/output/*/*.mp3 assets/mock/`
   
6. **Notify User**:
   - Inform the user that the fresh data is downloaded, aligned, and injected into the app's mock server files.
