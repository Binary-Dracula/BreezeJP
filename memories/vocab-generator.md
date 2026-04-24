# 单词生成器注意事项

- 单词生成器输出必须按 `moji_word_id` 去重，不能用 `word:reading` 作为唯一身份；源 reading 可能为空或被 AI 补全导致重复。
- 生成/归一化输出时统一写入 `_source_meta.moji_target_id`，并将 `4_conjugations` 的空值保留为 JSON `null`。
- `part_of_speech` 统一走脚本规范化，输出使用中文主格式，保留日语语法类目中的 い/な/サ 等常用标记。
