# 开发环境约定

- 单词数据流水线的新脚本依赖项目根 `.env` 读取密钥，见 `.agents/skills/_vocab_common/config.py`；删除 `.env` 会导致 scraper/generator/uploader 失效。
- 项目根 `.venv` 是词汇流水线默认 Python 环境；可重建但删除后需重新安装依赖。
- `.dart_tool`、`.dart-tool`、`.dartServer`、`build`、`api/workers/.wrangler` 都属于可重建缓存或本地产物，可安全清理。
