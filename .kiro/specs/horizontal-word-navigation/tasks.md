# Implementation Plan

- [x] 1. 更新常量定义
  - 在 `lib/core/constants/app_constants.dart` 中添加 `preloadThreshold` 常量（值为 5）
  - 确认 `defaultLearnCount` 常量已存在（值为 20）
  - _Requirements: 5.5_
  - _Note: defaultLearnCount 已存在，需添加 preloadThreshold_

- [x] 2. 扩展 LearnState 数据模型
  - 在 `lib/features/learn/state/learn_state.dart` 中添加 `isPreloading` 字段（bool，默认 false）
  - 添加 `hasMoreWords` 字段（bool，默认 true）
  - 添加 `learnedWordIds` 字段（Set<int>，默认空集合）
  - 添加 `isBatchCompleted` getter 方法
  - _Requirements: 5.1, 5.4, 4.1_
  - _Note: isBatchCompleted 已存在，需添加其他字段_

- [x] 3. 扩展 WordRepository 添加预加载方法
  - 在 `lib/data/repositories/word_repository.dart` 中添加 `getUnlearnedWords` 方法
  - 方法参数：limit (默认 20), excludeIds (默认空列表)
  - 查询逻辑：排除 study_words 表中 user_state > 0 的单词
  - 支持排除指定 ID 列表
  - _Requirements: 5.1, 5.2_

- [x] 4. 扩展 StudyWordRepository 添加标记方法
  - 在 `lib/data/repositories/study_word_repository.dart` 中添加 `markAsLearned` 方法
  - 方法参数：userId, wordId
  - 插入或更新 study_words 表，设置 user_state = 1
  - 使用 ConflictAlgorithm.replace 处理重复
  - _Requirements: 4.2_
  - _Note: 已有 createStudyWord 和 updateStudyWord 方法可实现此功能_

- [x] 5. 扩展 StudyLogRepository 添加日志方法
  - 在 `lib/data/repositories/study_log_repository.dart` 中添加 `insertLog` 方法
  - 方法参数：userId, wordId, logType, durationMs (可选)
  - 插入 study_logs 表，logType = 1 表示初学
  - _Requirements: 4.3_
  - _Note: 已有 createLog 方法可实现此功能_

- [x] 6. 扩展 DailyStatRepository 添加统计方法
  - 在 `lib/data/repositories/daily_stat_repository.dart` 中添加 `updateDailyStats` 方法
  - 方法参数：userId, learnedCount, durationMs
  - 查询当天是否已有记录
  - 如果没有记录，创建新记录
  - 如果有记录，累加更新 total_study_time_ms 和 learned_words_count
  - _Requirements: 6.3, 6.4, 6.5, 6.6_
  - _Note: 已有 getOrCreateTodayStat, updateDailyStat 等方法可实现此功能_

- [x] 7. 更新 LearnController 添加核心方法
- [x] 7.1 添加 markWordAsLearned 方法
  - 更新内存状态：将 wordId 添加到 learnedWordIds 集合
  - 调用 StudyWordRepository 方法更新数据库
  - 调用 StudyLogRepository 方法插入日志
  - _Requirements: 4.1, 4.2, 4.3_
  - _Note: 当前 submitAnswer 方法已实现类似功能，需重构为独立方法_

- [x] 7.2 添加 checkAndPreload 方法
  - 检查是否正在预加载或没有更多单词，如果是则返回
  - 计算剩余单词数：studyQueue.length - currentIndex - 1
  - 如果剩余单词数 > preloadThreshold，则返回
  - 设置 isPreloading = true
  - 调用 WordRepository.getUnlearnedWords 加载新单词
  - 如果返回空列表，设置 hasMoreWords = false
  - 如果成功，将新单词追加到 studyQueue
  - _Requirements: 5.1, 5.2, 5.6_

- [x] 7.3 添加 onPageChanged 方法
  - 如果是向前滑动（newIndex > currentIndex），标记上一个单词为已学习
  - 检查单词是否已在 learnedWordIds 中，避免重复标记
  - 更新 currentIndex 为 newIndex
  - 调用 checkAndPreload 检查是否需要预加载
  - _Requirements: 1.1, 1.2, 4.1, 4.4, 5.1_

- [x] 7.4 添加 updateDailyStats 方法
  - 方法参数：durationMs, learnedCount
  - 调用 DailyStatRepository 方法更新统计
  - _Requirements: 6.3, 6.4_
  - _Note: 当前在 submitAnswer 中已实现，需确保在 dispose 时也调用_

- [x] 7.5 添加 endSession 方法
  - 清空当前状态
  - 重置学习队列和索引
  - _Requirements: 7.2_
  - _Note: 已实现_

- [x] 8. 重构 LearnPage 为水平滑动布局
- [x] 8.1 添加 PageController 和会话开始时间
  - 在 _LearnPageState 中添加 _pageController 字段
  - 在 _LearnPageState 中添加 _sessionStartTime 字段
  - 在 initState 中初始化 PageController
  - 在 initState 中记录会话开始时间
  - _Requirements: 1.1, 6.1_

- [x] 8.2 实现 dispose 方法保存统计数据
  - 计算学习时长：DateTime.now() - _sessionStartTime
  - 获取已学习单词数：learnedWordIds.length
  - 调用 LearnController 方法更新统计
  - 释放 PageController
  - _Requirements: 6.2, 6.3, 6.4, 7.3_

- [x] 8.3 替换 body 为 PageView.builder
  - 移除现有的 ListView 布局
  - 使用 PageView.builder 替代
  - 设置 controller 为 _pageController
  - 设置 itemCount 为 studyQueue.length
  - 在 onPageChanged 回调中调用 HapticFeedback.lightImpact()
  - 在 onPageChanged 回调中调用 LearnController.onPageChanged
  - _Requirements: 1.1, 1.2, 1.4_

- [x] 8.4 在 PageView.builder 的 itemBuilder 中构建单词页面
  - 使用 SingleChildScrollView 包裹内容，支持垂直滚动，添加 padding
  - 内部使用 Column 包含现有的 WordCard 和 ExampleCard 组件
  - WordCard 需要传入：wordDetail, isPlayingAudio, onPlayAudio
  - ExampleCard 需要传入：example, index, isPlaying, onPlayAudio
  - 使用 asMap().entries 遍历例句列表以获取索引
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 8.5 更新 AppBar 显示序号
  - 移除进度显示（如 "3/10"）
  - 改为显示当前序号（如 "第 15 个"）
  - 使用 currentIndex + 1 计算序号
  - 当队列为空时不显示序号
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 8.6 移除底部导航栏
  - 删除 _buildNavigationBar 方法
  - 删除底部的"下一个"和"完成"按钮
  - _Requirements: 1.1_

- [x] 8.7 简化完成界面
  - 在 _buildFinishedScreen 中移除"继续学习"按钮
  - 只保留"返回首页"按钮
  - 移除统计信息显示
  - _Requirements: 7.1, 7.2_

- [x] 9. Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户

- [x] 10. 编写单元测试
- [x] 10.1 测试 LearnController.markWordAsLearned
  - 测试成功标记时更新内存状态
  - 测试成功标记时调用 repository 方法
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 10.2 测试 LearnController.checkAndPreload
  - 测试在正确时机触发预加载
  - 测试预加载成功时追加单词
  - 测试防止重复预加载
  - _Requirements: 5.1, 5.2, 5.6_

- [x] 10.3 测试 LearnController.onPageChanged
  - 测试向前滑动时标记单词
  - 测试更新索引
  - 测试触发预加载检查
  - 测试不重复标记已学习单词
  - _Requirements: 1.1, 1.2, 4.1, 4.4_

- [x] 10.4 测试 Repository 方法
  - 测试 WordRepository.getUnlearnedWords 过滤和排除逻辑
  - 测试 StudyWordRepository.markAsLearned 数据库操作
  - 测试 StudyLogRepository.insertLog 日志插入
  - 测试 DailyStatRepository.updateDailyStats 首次和累加更新
  - _Requirements: 5.1, 4.2, 4.3, 6.5, 6.6_

- [ ]* 11. 编写属性测试
- [ ]* 11.1 属性测试：向左滑动递增索引
  - **Property 1: 向左滑动递增索引**
  - **Validates: Requirements 1.1**
  - 生成随机学习队列和索引
  - 模拟向左滑动
  - 验证索引递增 1
  - 运行至少 100 次迭代

- [ ]* 11.2 属性测试：向右滑动递减索引
  - **Property 2: 向右滑动递减索引**
  - **Validates: Requirements 1.2**
  - 生成随机学习队列和索引（不为 0）
  - 模拟向右滑动
  - 验证索引递减 1
  - 运行至少 100 次迭代

- [ ]* 11.3 属性测试：序号显示正确性
  - **Property 3: 序号显示正确性**
  - **Validates: Requirements 3.1, 3.2, 3.3**
  - 生成随机索引
  - 验证显示序号 = 索引 + 1
  - 运行至少 100 次迭代

- [ ]* 11.4 属性测试：滑动自动标记学习状态
  - **Property 4: 滑动自动标记学习状态**
  - **Validates: Requirements 4.1**
  - 生成随机单词
  - 模拟滑动离开
  - 验证单词被添加到已学习集合
  - 运行至少 100 次迭代

- [ ]* 11.5 属性测试：标记学习状态更新数据库
  - **Property 5: 标记学习状态更新数据库**
  - **Validates: Requirements 4.2**
  - 生成随机单词
  - 标记为已学习
  - 验证 study_words 表有记录
  - 运行至少 100 次迭代

- [ ]* 11.6 属性测试：标记学习状态插入日志
  - **Property 6: 标记学习状态插入日志**
  - **Validates: Requirements 4.3**
  - 生成随机单词
  - 标记为已学习
  - 验证 study_logs 表有记录
  - 运行至少 100 次迭代

- [ ]* 11.7 属性测试：不重复标记已学习单词
  - **Property 7: 不重复标记已学习单词**
  - **Validates: Requirements 4.4**
  - 生成随机单词
  - 多次标记同一单词
  - 验证只有一条记录
  - 运行至少 100 次迭代



- [ ]* 11.8 属性测试：预加载触发条件
  - **Property 8: 预加载触发条件**
  - **Validates: Requirements 5.1**
  - 生成随机队列
  - 设置索引到倒数第 5 个
  - 验证触发预加载
  - 运行至少 100 次迭代

- [ ]* 11.10 属性测试：预加载追加单词
  - **Property 10: 预加载追加单词**
  - **Validates: Requirements 5.2**
  - 生成随机队列
  - 触发预加载
  - 验证队列长度增加
  - 运行至少 100 次迭代

- [ ]* 11.11 属性测试：预加载失败不影响学习
  - **Property 11: 预加载失败不影响学习**
  - **Validates: Requirements 5.3**
  - 模拟预加载失败
  - 验证不影响当前学习
  - 运行至少 100 次迭代

- [ ]* 11.12 属性测试：防止重复预加载
  - **Property 12: 防止重复预加载**
  - **Validates: Requirements 5.6**
  - 生成有足够单词的队列
  - 尝试触发预加载
  - 验证不重复加载
  - 运行至少 100 次迭代

- [ ]* 11.13 属性测试：记录学习开始时间
  - **Property 13: 记录学习开始时间**
  - **Validates: Requirements 6.1**
  - 进入学习页面
  - 验证记录了开始时间
  - 运行至少 100 次迭代

- [ ]* 11.14 属性测试：计算学习时长
  - **Property 14: 计算学习时长**
  - **Validates: Requirements 6.2**
  - 记录开始和结束时间
  - 验证时长计算正确
  - 运行至少 100 次迭代

- [ ]* 11.15 属性测试：更新每日统计
  - **Property 15: 更新每日统计**
  - **Validates: Requirements 6.3, 6.4**
  - 生成随机学习数据
  - 更新统计
  - 验证数据库记录正确
  - 运行至少 100 次迭代

- [ ]* 11.16 属性测试：累加更新每日统计
  - **Property 16: 累加更新每日统计**
  - **Validates: Requirements 6.6**
  - 创建已有记录
  - 再次更新统计
  - 验证累加而非覆盖
  - 运行至少 100 次迭代

- [ ]* 11.17 属性测试：保存统计数据
  - **Property 17: 保存统计数据**
  - **Validates: Requirements 7.3**
  - 完成学习会话
  - 返回首页
  - 验证统计数据已保存
  - 运行至少 100 次迭代

- [x] 12. Final Checkpoint - 确保所有测试通过
  - 确保所有测试通过，如有问题请询问用户
