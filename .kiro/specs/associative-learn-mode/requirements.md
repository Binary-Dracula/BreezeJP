# Requirements Document

## Introduction

本需求文档定义了 BreezeJP 的语义分支学习模式（Associative Learn Mode）功能。该功能实现无尽探索式的单词学习体验，用户从随机起点开始，通过关联词链条进行无限学习，形成语义网络记忆。核心理念是"学完狗推荐猫"，让用户在关联中自然记忆单词。

## Glossary

- **AssociativeLearnMode**: 语义分支学习模式，用户通过关联词链条进行无尽探索学习
- **InitialChoicePage**: 初始选择页，展示 5 个随机单词供用户选择起点
- **LearnPage**: 学习页面，全屏展示单词详情，支持左右滑动切换
- **StudyQueue**: 学习队列，包含当前单词的所有关联词
- **WordRelation**: 单词关联关系，存储在 word_relations 表中
- **RelatedWord**: 关联单词，通过 word_relations 表关联的单词
- **ChainBreak**: 断链，当最后一个单词没有关联词时发生

## Requirements

### Requirement 1

**User Story:** 作为用户，我想从 5 个随机单词中选择一个作为学习起点，这样我可以自由选择感兴趣的方向开始探索。

#### Acceptance Criteria

1. WHEN 用户进入语义分支学习模式 THEN THE InitialChoicePage SHALL 从数据库随机获取 5 个未掌握的单词
2. WHEN 初始选择页加载完成 THEN THE InitialChoicePage SHALL 以卡片形式展示 5 个单词选项，每个卡片显示单词、假名、第一个中文释义和 JLPT 等级标签
3. WHEN 用户点击刷新按钮 THEN THE InitialChoicePage SHALL 重新随机获取 5 个未掌握的单词并更新显示
4. WHEN 用户点击其中一个单词卡片 THEN THE InitialChoicePage SHALL 导航到该单词的学习页面
5. WHEN 用户选择单词后 THEN THE AssociativeLearnMode SHALL 加载该单词的所有关联词到学习队列

### Requirement 2

**User Story:** 作为用户，我想在学习页面通过左右滑动切换单词、上下滑动查看详情，这样我可以获得流畅的沉浸式学习体验。

#### Acceptance Criteria

1. WHEN 用户进入单词学习页面 THEN THE LearnPage SHALL 加载并展示单词的完整数据，包括：
   - words 表：单词、假名、罗马音、JLPT 等级、词性、音调
   - word_meanings 表：所有释义（按 definition_order 排序）
   - word_audio 表：单词音频（用户可点击播放）
   - example_sentences 表：所有例句及翻译
   - example_audio 表：例句音频（用户可点击播放）
2. WHEN 用户点击音频播放按钮 THEN THE LearnPage SHALL 使用 AudioService 播放对应音频
3. WHEN 音频播放状态改变 THEN THE LearnPage SHALL 根据 AudioService.currentState（AudioStateEnum）自动更新播放按钮的显示状态（未播放/播放中）
4. WHEN 用户在学习页面向上滑动 THEN THE LearnPage SHALL 滚动显示下方的例句和详细内容
5. WHEN 用户在学习页面向下滑动 THEN THE LearnPage SHALL 滚动显示上方的单词基本信息
6. WHEN 用户在学习页面向左滑动 THEN THE LearnPage SHALL 切换到学习队列中的下一个关联词
7. WHEN 用户在学习页面向右滑动 THEN THE LearnPage SHALL 切换到学习队列中的上一个单词
8. WHEN 页面切换完成 THEN THE LearnPage SHALL 触发轻微的触觉反馈

### Requirement 3

**User Story:** 作为用户，我想在学完当前队列后自动加载新的关联词，这样我可以无缝连续探索而不被打断。

#### Acceptance Criteria

1. WHEN 用户学习到队列中的最后一个单词 THEN THE AssociativeLearnMode SHALL 基于该单词加载其所有关联词
2. WHEN 关联词加载完成 THEN THE AssociativeLearnMode SHALL 将新关联词追加到学习队列末尾
3. WHEN 加载关联词时 THEN THE AssociativeLearnMode SHALL 过滤掉已掌握的单词（user_state = 2）
4. WHEN 最后一个单词没有关联词 THEN THE AssociativeLearnMode SHALL 显示"已探索完这条路径"提示并返回初始选择页

### Requirement 4

**User Story:** 作为用户，我想在滑动切换单词时自动记录学习状态，这样我可以专注于学习内容而不需要额外操作。

#### Acceptance Criteria

1. WHEN 用户通过滑动离开当前单词 THEN THE LearnPage SHALL 将该单词标记为学习中（user_state = 1）
2. WHEN 单词被标记为学习中 THEN THE LearnPage SHALL 更新 study_words 表中的学习状态
3. WHEN 单词被标记为学习中 THEN THE LearnPage SHALL 在 study_logs 表中插入学习日志（log_type = 1）
4. WHEN 用户向右滑动返回已标记的单词 THEN THE LearnPage SHALL 不重复标记该单词

### Requirement 5

**User Story:** 作为用户，我想看到当前学习的进度信息，这样我可以知道本次探索学习了多少单词。

#### Acceptance Criteria

1. WHEN 用户在学习页面 THEN THE LearnPage SHALL 在右上角显示本次已学单词数（如 "+5"）
2. WHEN 用户切换到新单词 THEN THE LearnPage SHALL 更新已学单词计数
3. WHEN 用户点击关闭按钮 THEN THE LearnPage SHALL 结束学习会话并返回首页

### Requirement 6

**User Story:** 作为用户，我想系统自动记录我的学习统计数据，这样我可以追踪我的学习进度。

#### Acceptance Criteria

1. WHEN 用户进入学习页面 THEN THE LearnPage SHALL 记录学习开始时间
2. WHEN 用户离开学习页面 THEN THE LearnPage SHALL 计算本次学习时长并更新 daily_stats 表
3. WHEN 用户离开学习页面 THEN THE LearnPage SHALL 更新 daily_stats 表中的已学单词数
4. WHEN 当天首次学习 THEN THE LearnPage SHALL 在 daily_stats 表中创建新记录
5. WHEN 当天非首次学习 THEN THE LearnPage SHALL 累加更新 daily_stats 表中的现有记录
