# 数据仓库 (Repositories)

本目录包含应用程序的数据仓库层，负责封装所有数据库操作，为业务逻辑层提供清晰的数据访问接口。

## 目录结构

*   **`word_repository.dart`**: 单词数据仓库
*   **`study_word_repository.dart`**: 学习进度数据仓库
*   **`study_log_repository.dart`**: 学习日志数据仓库
*   **`daily_stat_repository.dart`**: 每日统计数据仓库
*   **`user_repository.dart`**: 用户数据仓库
*   **`example_api_repository.dart`**: 示例 API 仓库 (用于演示或测试)

## 详细说明

### 1. WordRepository (单词数据仓库)

负责管理核心单词数据，包括单词的基本信息、释义、音频和例句。

*   **主要功能**:
    *   `getWordById`: 根据 ID 获取单词。
    *   `getWordsByLevel`: 根据 JLPT 等级获取单词列表。
    *   `searchWords`: 搜索单词（支持单词、假名、罗马音）。
    *   `getWordDetail`: 获取单词的完整详情（包含释义、音频、例句）。
    *   `getRandomWords`: 随机获取单词（用于练习或测试）。
    *   `getWordCountByLevel`: 获取各等级的单词数量统计。

### 2. StudyWordRepository (学习进度数据仓库)

负责管理用户的单词学习进度，包括 SRS (间隔重复系统) 状态、复习时间等。支持 SM-2 和 FSRS 算法字段。

*   **主要功能**:
    *   `getStudyWord`: 获取指定单词的学习记录。
    *   `createStudyWord`: 创建新的学习记录。
    *   `updateStudyWord`: 更新学习记录。
    *   `getDueReviews`: 获取当前需要复习的单词列表。
    *   `getNewWords`: 获取待学习的新单词列表。
    *   `recordCorrectReview`: 记录复习成功，更新 SRS 参数（Interval, Ease Factor, Stability, Difficulty）。
    *   `recordIncorrectReview`: 记录复习失败，重置或调整 SRS 参数。
    *   `markAsMastered`: 标记单词为已掌握。
    *   `markAsIgnored`: 标记单词为忽略。
    *   `resetProgress`: 重置单词的学习进度。

### 3. StudyLogRepository (学习日志数据仓库)

负责记录每一次的学习行为，用于生成统计数据和分析学习习惯。

*   **主要功能**:
    *   `createLog`: 创建一条学习日志。
    *   `logFirstLearn`: 记录初次学习事件（支持 FSRS 参数）。
    *   `logReview`: 记录复习事件（支持 FSRS 参数）。
    *   `getDailyStatistics`: 获取每日学习统计数据。
    *   `getRatingDistribution`: 获取复习评分分布。
    *   `getTimeStatistics`: 获取学习时长统计。
    *   `getHeatmapData`: 获取学习热力图数据。

### 4. DailyStatRepository (每日统计数据仓库)

负责管理每日的学习汇总数据，用于快速展示进度和图表。

*   **主要功能**:
    *   `getDailyStat`: 获取指定日期的统计数据。
    *   `incrementStudyTime`: 增加学习时长（单位：毫秒）。
    *   `incrementLearnedWords`: 增加新学单词数。
    *   `incrementReviewedWords`: 增加复习单词数。
    *   `getWeeklySummary`: 获取本周学习汇总。
    *   `getMonthlySummary`: 获取本月学习汇总。
    *   `calculateStreak`: 计算连续学习天数。

### 5. UserRepository (用户数据仓库)

负责管理用户信息。

*   **主要功能**:
    *   `createUser`: 创建新用户。
    *   `getUserById`: 根据 ID 获取用户。
    *   `getUserByUsername`: 根据用户名获取用户。
    *   `updateUser`: 更新用户信息。
    *   `deleteUser`: 删除用户。

## 使用规范

1.  **依赖注入**: 建议通过 Provider 或 GetIt 等依赖注入方式使用 Repository，避免直接实例化。
2.  **异常处理**: 所有 Repository 方法在发生数据库错误时会抛出异常，调用层应做好 try-catch 处理。
3.  **日志记录**: Repository 内部已集成 `AppLogger`，会自动记录关键的数据库操作和错误信息。
4.  **数据一致性**: 涉及多个表的操作（如同时更新进度和记录日志），建议在业务逻辑层（Service/Bloc）进行协调，或在 Repository 中使用事务（Transaction）。
