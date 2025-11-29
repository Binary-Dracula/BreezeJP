# Implementation Plan

## 1. 数据层扩展

- [x] 1.1 创建 WordChoice 模型
  - 在 `lib/data/models/` 创建 `word_choice.dart`
  - 包含 `Word word` 和 `List<WordMeaning> meanings` 字段
  - 实现 `primaryMeaning` getter 返回第一个释义
  - _Requirements: 1.2_

- [x] 1.2 创建 WordWithRelation 模型
  - 在 `lib/data/models/` 创建 `word_with_relation.dart`
  - 包含 `Word word`、`double score`、`String relationType` 字段
  - 实现 `fromMap()` 方法
  - _Requirements: 3.1_

- [x] 1.3 扩展 WordRepository 添加初始选择查询方法
  - 在 `lib/data/repositories/word_repository.dart` 添加 `getRandomUnmasteredWordsWithMeaning()` 方法
  - 查询随机未掌握单词（user_state IS NULL OR user_state IN (0, 1)）
  - 为每个单词获取释义列表
  - 返回 `List<WordChoice>`
  - _Requirements: 1.1_

- [x] 1.4 扩展 WordRepository 添加关联词查询方法
  - 在 `lib/data/repositories/word_repository.dart` 添加 `getRelatedWords()` 方法
  - 查询 word_relations 表获取关联词
  - 过滤已掌握单词（user_state = 2）
  - 按 score 降序排列
  - 返回 `List<WordWithRelation>`
  - _Requirements: 3.1, 3.3_

- [x] 1.5 扩展 StudyWordRepository 添加标记学习方法
  - 在 `lib/data/repositories/study_word_repository.dart` 添加 `markAsLearned()` 方法
  - 插入或更新 study_words 表，设置 user_state = 1
  - _Requirements: 4.1, 4.2_

## 2. 音频状态机实现

- [x] 2.1 创建音频播放状态模型
  - 在 `lib/services/` 创建 `audio_play_state.dart`
  - 定义 `AudioPlayState` 枚举（idle, loading, playing, error）
  - 定义 `AudioPlayStatus` 类，包含 state、currentSource、errorMessage
  - 实现 `isPlaying(source)` 和 `isLoading(source)` 方法
  - _Requirements: 2.2, 2.3_

- [x] 2.2 创建 AudioPlayController 状态机
  - 在 `lib/services/` 创建 `audio_play_controller.dart`
  - 继承 `Notifier<AudioPlayStatus>`
  - 实现 `play(source)`、`stop()`、`toggle(source)` 方法
  - 监听 `AudioPlayer.playerStateStream` 自动更新状态
  - 处理播放完成自动回到 idle 状态
  - _Requirements: 2.2, 2.3_

- [x] 2.3 创建 AudioPlayController Provider
  - 在 `lib/services/` 创建 `audio_play_controller_provider.dart`
  - 定义 `audioPlayControllerProvider`
  - _Requirements: 2.2, 2.3_

- [ ]* 2.4 编写音频状态机单元测试
  - 测试状态转换：idle → loading → playing → idle
  - 测试 toggle 方法切换逻辑
  - 测试播放完成自动回到 idle
  - _Requirements: 2.2, 2.3_

## 3. 初始选择页实现

- [x] 3.1 创建 InitialChoiceState
  - 在 `lib/features/learn/state/` 创建 `initial_choice_state.dart`
  - 包含 `List<WordChoice> choices`、`bool isLoading`、`String? error`
  - 实现 `copyWith()` 方法
  - _Requirements: 1.1_

- [x] 3.2 创建 InitialChoiceController
  - 在 `lib/features/learn/controller/` 创建 `initial_choice_controller.dart`
  - 继承 `Notifier<InitialChoiceState>`
  - 实现 `loadChoices()` 方法加载 5 个随机单词
  - 实现 `refresh()` 方法刷新选择
  - _Requirements: 1.1, 1.3_

- [x] 3.3 创建 WordChoiceCard 组件
  - 在 `lib/features/learn/widgets/` 创建 `word_choice_card.dart`
  - 显示单词、假名、第一个释义、JLPT 等级标签
  - 接收 `WordChoice` 和 `onTap` 回调
  - _Requirements: 1.2_

- [x] 3.4 创建 InitialChoicePage 页面
  - 在 `lib/features/learn/pages/` 创建 `initial_choice_page.dart`
  - 沉浸式设计，无 AppBar
  - 顶部操作栏：返回按钮、刷新按钮
  - 页面标题和副标题
  - GridView 展示 5 个 WordChoiceCard
  - 点击卡片导航到学习页
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ]* 3.5 编写初始选择页单元测试
  - 测试 loadChoices 加载 5 个单词
  - 测试 refresh 重新加载
  - _Requirements: 1.1, 1.3_

## 4. 学习页状态管理

- [x] 4.1 创建 LearnState
  - 在 `lib/features/learn/state/` 创建 `learn_state.dart`
  - 包含 studyQueue、currentIndex、learnedWordIds、isLoading、isLoadingMore、pathEnded、error
  - 实现 `currentWordDetail`、`learnedCount`、`isAtQueueEnd` getter
  - 实现 `copyWith()` 方法
  - _Requirements: 2.1, 4.1, 5.1_

- [x] 4.2 创建 LearnController
  - 在 `lib/features/learn/controller/` 创建 `learn_controller.dart`
  - 继承 `Notifier<LearnState>`
  - 注入 WordRepository、StudyWordRepository、StudyLogRepository、DailyStatRepository
  - 记录 sessionStartTime
  - _Requirements: 2.1, 4.1, 6.1_

- [x] 4.3 实现 LearnController.initWithWord 方法
  - 接收 wordId 参数
  - 记录 sessionStartTime
  - 加载单词详情
  - 加载关联词
  - 初始化 studyQueue
  - _Requirements: 1.5, 2.1_

- [x] 4.4 实现 LearnController.onPageChanged 方法
  - 更新 currentIndex
  - 向前滑动时标记上一个单词为已学习
  - 检查是否到达队列末尾，触发加载更多
  - 触发触觉反馈
  - _Requirements: 2.4, 2.5, 2.8, 4.1_

- [x] 4.5 实现 LearnController.loadRelatedWords 方法
  - 加载当前单词的关联词
  - 如果关联词为空，设置 pathEnded = true
  - 否则追加到 studyQueue
  - _Requirements: 3.1, 3.2, 3.4_

- [x] 4.6 实现 LearnController.markWordAsLearned 方法
  - 检查是否已在 learnedWordIds 中，避免重复标记
  - 更新 learnedWordIds
  - 调用 StudyWordRepository 更新数据库
  - 调用 StudyLogRepository 插入日志
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 4.7 实现 LearnController.updateDailyStats 方法
  - 计算学习时长
  - 调用 DailyStatRepository 更新统计
  - _Requirements: 6.2, 6.3, 6.4, 6.5_

- [ ]* 4.8 编写 LearnController 单元测试
  - 测试 initWithWord 初始化队列
  - 测试 onPageChanged 索引更新和标记
  - 测试 loadRelatedWords 追加队列
  - 测试 markWordAsLearned 不重复标记
  - _Requirements: 2.4, 2.5, 3.1, 3.2, 4.1, 4.4_

## 5. 学习页 UI 组件

- [x] 5.1 创建 AudioPlayButton 组件
  - 在 `lib/features/learn/widgets/` 创建 `audio_play_button.dart`
  - 基于 AudioPlayController 状态机
  - 显示播放/停止/加载图标
  - 点击调用 toggle(source)
  - _Requirements: 2.2, 2.3_

- [x] 5.2 创建 WordCard 组件
  - 在 `lib/features/learn/widgets/` 创建 `word_card.dart`
  - 显示单词、假名、罗马音、词性、音调
  - 显示所有释义
  - 包含单词音频播放按钮
  - _Requirements: 2.1_

- [x] 5.3 创建 ExampleCard 组件
  - 在 `lib/features/learn/widgets/` 创建 `example_card.dart`
  - 显示例句、假名、翻译
  - 包含例句音频播放按钮
  - _Requirements: 2.1_

- [x] 5.4 创建 LearnPage 页面
  - 在 `lib/features/learn/pages/` 创建 `learn_page.dart`
  - 沉浸式设计，无 AppBar
  - 顶部操作栏：关闭按钮、已学计数
  - PageView.builder 水平滑动切换单词
  - SingleChildScrollView 垂直滚动查看详情
  - 路径结束时显示对话框
  - _Requirements: 2.1, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1, 5.2, 5.3_

- [x] 5.5 实现 LearnPage 生命周期管理
  - initState 中调用 initWithWord
  - dispose 中调用 updateDailyStats
  - _Requirements: 6.1, 6.2, 6.3_

## 6. 路由配置

- [x] 6.1 配置学习模块路由
  - 在 `lib/router/app_router.dart` 添加 `/initial-choice` 路由
  - 修改 `/learn/:wordId` 路由，解析 wordId 参数
  - 移除旧的 `/learn` 路由（带 jlptLevel 参数）
  - _Requirements: 1.4_

## 7. Checkpoint - 确保所有测试通过
- [x] 7. Checkpoint
  - 确保所有测试通过，如有问题请询问用户

## 8. 属性测试

- [ ]* 8.1 属性测试：初始选择返回未掌握单词
  - **Property 1: 初始选择返回未掌握单词**
  - **Validates: Requirements 1.1**
  - 生成随机数据库状态
  - 验证返回的单词都是未掌握的
  - 运行至少 100 次迭代

- [ ]* 8.2 属性测试：选择单词后加载关联词
  - **Property 2: 选择单词后加载关联词**
  - **Validates: Requirements 1.5**
  - 生成随机单词和关联关系
  - 验证队列包含所有关联词
  - 运行至少 100 次迭代

- [ ]* 8.3 属性测试：向左滑动递增索引
  - **Property 5: 向左滑动递增索引**
  - **Validates: Requirements 2.6**
  - 生成随机队列和索引
  - 验证索引递增 1
  - 运行至少 100 次迭代

- [ ]* 8.4 属性测试：向右滑动递减索引
  - **Property 6: 向右滑动递减索引**
  - **Validates: Requirements 2.7**
  - 生成随机队列和非零索引
  - 验证索引递减 1
  - 运行至少 100 次迭代

- [ ]* 8.5 属性测试：关联词过滤已掌握单词
  - **Property 9: 关联词过滤已掌握单词**
  - **Validates: Requirements 3.3**
  - 生成包含已掌握单词的关联关系
  - 验证返回的关联词不包含已掌握单词
  - 运行至少 100 次迭代

- [ ]* 8.6 属性测试：滑动离开标记学习状态
  - **Property 10: 滑动离开标记学习状态**
  - **Validates: Requirements 4.1**
  - 生成随机单词
  - 模拟滑动离开
  - 验证单词被添加到 learnedWordIds
  - 运行至少 100 次迭代

- [ ]* 8.7 属性测试：不重复标记已学习单词
  - **Property 13: 不重复标记已学习单词**
  - **Validates: Requirements 4.4**
  - 生成已在 learnedWordIds 中的单词
  - 模拟再次滑动离开
  - 验证不重复调用 markWordAsLearned
  - 运行至少 100 次迭代

- [ ]* 8.8 属性测试：已学计数等于集合大小
  - **Property 14: 已学计数等于集合大小**
  - **Validates: Requirements 5.1, 5.2**
  - 生成随机 learnedWordIds
  - 验证 learnedCount == learnedWordIds.length
  - 运行至少 100 次迭代

## 9. Final Checkpoint - 确保所有测试通过
- [ ] 9. Final Checkpoint
  - 确保所有测试通过，如有问题请询问用户
