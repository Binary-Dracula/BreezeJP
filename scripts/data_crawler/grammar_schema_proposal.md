# 新版语法结构数据库表设计方案 (SQLite)

基于我们最新爬取的详尽、结构化、双语 JSON 数据，以及考虑到未来可能的扩展性 (比如增加发音、同义法辨析、错题本等)，我为您设计了如下的表结构。

该结构采用了**完全重建、高度范式化（Normalized）**的设计，将原本糅杂在一起的提示、限制和例句拆分成独立的关联表。

---

### 1. `grammars` (语法主表)
核心语法条目。

| 字段名            | 类型                                | 说明                                                     |
| :---------------- | :---------------------------------- | :------------------------------------------------------- |
| `id`              | `INTEGER PRIMARY KEY AUTOINCREMENT` | 语法唯一标识 (自增)                                      |
| `title`           | `TEXT NOT NULL`                     | 语法内容，例如：`です`                                   |
| `jlpt_level`      | `TEXT`                              | 考级水平，例如：`n5`                                     |
| `usage_frequency` | `INTEGER DEFAULT 0`                 | 使用频率星级或数值权重，对应 JSON 里的 `usage_frequency` |
| `created_at`      | `INTEGER`                           | 创建时间戳                                               |
| `updated_at`      | `INTEGER`                           | 更新时间戳                                               |

---

### 2. `grammar_meanings` (语法语义表)
由于一个语法可能有多个核心含义，甚至不同接续代表不同含义，特将含义单独抽表。

| 字段名          | 类型                                | 说明                                       |
| :-------------- | :---------------------------------- | :----------------------------------------- |
| `id`            | `INTEGER PRIMARY KEY AUTOINCREMENT` | 语义唯一标识 (自增)                        |
| `grammar_id`    | `INTEGER NOT NULL`                  | 关联语法 ID (Foreign Key -> `grammars.id`) |
| `sort_order`    | `INTEGER DEFAULT 1`                 | 排序优先级，应对一个语法多条解释时用       |
| `definition_cn` | `TEXT`                              | 中文含义翻译                               |
| `definition_en` | `TEXT`                              | 英文含义对照                               |
| `how_to_use_cn` | `TEXT`                              | 中文接续公式与说明                         |
| `how_to_use_en` | `TEXT`                              | 英文接续对照                               |

> *注：将原有的 `tip` 和 `context` 拆分到了下方的 `grammar_contexts` 表中，以支持更加结构化的展示。*

---

### 3. `grammar_contexts` (语境与限制表 - **新增**)
专门用于存储非常重要的 “使用情景(when to use)” 和 “限制要求(limitations)”。未来如果新增“同义近义词对比”，也可以扩展到该范畴。

| 字段名             | 类型                                | 说明                                                                                                                                            |
| :----------------- | :---------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`               | `INTEGER PRIMARY KEY AUTOINCREMENT` | 自增标识                                                                                                                                        |
| `grammar_id`       | `INTEGER NOT NULL`                  | 关联语法 ID (Foreign Key -> `grammars.id`)                                                                                                      |
| `when_to_use_cn`   | `TEXT`                              | 中文使用情景说明                                                                                                                                |
| `when_to_use_en`   | `TEXT`                              | 英文使用情景说明                                                                                                                                |
| `limitations_json` | `TEXT`                              | 限制条件 (由于往往是数组，这里存为 JSON String 或者拆成分表。推荐存为序列化 JSON: `["条件1", "条件2"]` 配合 Flutter 的 `jsonDecode` 解析最灵活) |

---

### 4. `grammar_examples` (例句表)
保存中、英、日三语例句。

| 字段名           | 类型                                | 说明                                                                 |
| :--------------- | :---------------------------------- | :------------------------------------------------------------------- |
| `id`             | `INTEGER PRIMARY KEY AUTOINCREMENT` | 例句唯一标识 (自增)                                                  |
| `grammar_id`     | `INTEGER NOT NULL`                  | 关联语法 ID (便于直接提取该语法下的所有例句)                         |
| `meaning_id`     | `INTEGER`                           | 关联语义 ID (可选：如果以后想要实现“例句严格挂载在某一个特定含义下”) |
| `sort_order`     | `INTEGER DEFAULT 1`                 | 展示顺序                                                             |
| `sentence`       | `TEXT`                              | 日文例句内容 (需转换为 Ruby 注音格式，如 漢字[かんじ])               |
| `translation_cn` | `TEXT`                              | 中文翻译                                                             |
| `translation_en` | `TEXT`                              | 英文翻译对照                                                         |
| `audio_url`      | `TEXT`                              | 预留未来扩展发音的音频URL字段                                        |

---

### 5. `study_grammars` (用户进度表 - **全新开始**)
由于您确认不需要迁移现有数据，该表的所有历史进度都可以随新语法的灌入而直接清空（或重建）。

| 字段名                        | 类型                                | 说明                                                                                                                  |
| :---------------------------- | :---------------------------------- | :-------------------------------------------------------------------------------------------------------------------- |
| `id`                          | `INTEGER PRIMARY KEY AUTOINCREMENT` | 学习记录的自增主键                                                                                                    |
| `user_id`                     | `INTEGER NOT NULL`                  | 用户系统挂载                                                                                                          |
| `grammar_id`                  | `INTEGER NOT NULL`                  | 关联到**新结构下**的 `grammars.id`                                                                                    |
| `learning_status`             | `INTEGER DEFAULT 0`                 | 学习进度 (比如 0:未学, 1:学习中, 2:已掌握)                                                                            |
| ...                           |                                     | 保留原有的基于 SRS 间隔重复算法的所有字段（`next_review_at`, `ease_factor`, `interval`, `stability`, `difficulty`等） |
| `UNIQUE(user_id, grammar_id)` |                                     | 唯一约束                                                                                                              |

---

**复审完成**：
1. `limitations_json` 已确认直接存储 JSON String，由宿主 App 在使用时 Decode 为对象。
2. 表结构已移除 `url` 字段。
3. 日文例句 `sentence` 需要转换为 Ruby 注音模式。
