# Requirements Document

## Introduction

本需求文档定义了 BreezeJP 学习页面的水平滑动导航功能。该功能将当前的垂直列表布局改为全屏沉浸式的水平翻页体验，用户通过左右滑动在单词之间切换，通过上下滑动查看单词详情，实现类似 TikTok 的心流体验。

## Glossary

- **LearnPage**: 学习页面组件，用户进行单词学习的主界面
- **PageView**: Flutter 的翻页组件，支持水平或垂直滚动
- **WordCard**: 单词卡片组件，展示单词的基本信息
- **ExampleCard**: 例句卡片组件，展示单词的例句
- **StudyQueue**: 学习队列，包含当前批次需要学习的单词列表
- **HapticFeedback**: 触觉反馈，在页面切换时提供震动反馈

## Requirements

### Requirement 1

**User Story:** 作为用户，我想通过左右滑动在单词之间切换，这样我可以获得流畅的沉浸式学习体验。

#### Acceptance Criteria

1. WHEN 用户在学习页面向左滑动 THEN THE LearnPage SHALL 切换到下一个单词并显示其完整内容
2. WHEN 用户在学习页面向右滑动 THEN THE LearnPage SHALL 切换到上一个单词并显示其完整内容
3. WHEN 用户在第一个单词时向右滑动 THEN THE LearnPage SHALL 保持在第一个单词不切换
4. WHEN 页面切换完成 THEN THE LearnPage SHALL 触发轻微的触觉反馈

### Requirement 2

**User Story:** 作为用户，我想在单个单词页面内上下滑动查看详情，这样我可以在不离开当前单词的情况下浏览所有信息。

#### Acceptance Criteria

1. WHEN 用户在单词页面内向上滑动 THEN THE LearnPage SHALL 滚动显示下方的例句内容
2. WHEN 用户在单词页面内向下滑动 THEN THE LearnPage SHALL 滚动显示上方的单词基本信息
3. WHEN 单词内容超出屏幕高度 THEN THE LearnPage SHALL 允许垂直滚动查看完整内容
4. WHEN 单词内容未超出屏幕高度 THEN THE LearnPage SHALL 禁用垂直滚动

### Requirement 3

**User Story:** 作为用户，我想看到当前学习的单词序号，这样我可以知道自己已经学习了多少个单词。

#### Acceptance Criteria

1. WHEN 用户查看学习页面 THEN THE LearnPage SHALL 在顶部显示当前单词序号（如 "第 15 个"）
2. WHEN 用户切换到下一个单词 THEN THE LearnPage SHALL 更新序号显示递增 1
3. WHEN 用户切换到上一个单词 THEN THE LearnPage SHALL 更新序号显示递减 1
4. WHEN 学习队列为空 THEN THE LearnPage SHALL 不显示序号指示器

### Requirement 4

**User Story:** 作为用户，我想在滑动切换单词时自动标记学习状态，这样我可以专注于学习内容而不需要额外操作。

#### Acceptance Criteria

1. WHEN 用户通过滑动离开当前单词 THEN THE LearnPage SHALL 自动标记该单词为已学习
2. WHEN 单词被标记为已学习 THEN THE LearnPage SHALL 更新 study_words 表中的学习状态
3. WHEN 单词被标记为已学习 THEN THE LearnPage SHALL 在 study_logs 表中插入学习日志记录
4. WHEN 用户向右滑动返回已学习的单词 THEN THE LearnPage SHALL 不重复标记该单词
5. WHEN 标记学习状态失败 THEN THE LearnPage SHALL 记录错误但不中断用户体验

### Requirement 5

**User Story:** 作为用户，我想在接近学完当前批次时自动加载更多单词，这样我可以无缝连续学习而不被打断。

#### Acceptance Criteria

1. WHEN 用户学习到倒数第 5 个单词 THEN THE LearnPage SHALL 自动在后台加载下一批 20 个单词
2. WHEN 后台加载完成 THEN THE LearnPage SHALL 将新单词追加到学习队列末尾
3. WHEN 后台加载失败 THEN THE LearnPage SHALL 记录错误但不影响当前学习流程
4. WHEN 没有更多单词可加载且用户学完所有已加载单词 THEN THE LearnPage SHALL 显示完成界面
5. WHEN 预加载阈值常量需要配置 THEN THE AppConstants SHALL 定义 preloadThreshold 常量值为 5
6. WHEN 预加载触发时队列中已有足够单词 THEN THE LearnPage SHALL 跳过重复加载

### Requirement 6

**User Story:** 作为用户，我想系统自动记录我的学习数据，这样我可以追踪我的学习进度和统计信息。

#### Acceptance Criteria

1. WHEN 用户进入学习页面开始学习 THEN THE LearnPage SHALL 记录学习开始时间
2. WHEN 用户离开学习页面 THEN THE LearnPage SHALL 计算本次学习时长
3. WHEN 用户离开学习页面 THEN THE LearnPage SHALL 更新 daily_stats 表中的学习时长
4. WHEN 用户离开学习页面 THEN THE LearnPage SHALL 更新 daily_stats 表中的已学单词数
5. WHEN 当天首次学习 THEN THE LearnPage SHALL 在 daily_stats 表中创建新记录
6. WHEN 当天非首次学习 THEN THE LearnPage SHALL 累加更新 daily_stats 表中的现有记录

### Requirement 7

**User Story:** 作为用户，我想在学完数据库所有单词后看到完成界面，这样我可以返回首页。

#### Acceptance Criteria

1. WHEN 数据库中所有符合条件的单词都已学习完成 THEN THE LearnPage SHALL 显示完成界面
2. WHEN 用户在完成界面点击"返回首页" THEN THE LearnPage SHALL 结束学习会话并返回首页
3. WHEN 用户返回首页 THEN THE LearnPage SHALL 保存本次学习的统计数据
