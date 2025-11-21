# 学习系统数据表总结

## 概述

BreezeJP 的学习系统包含两个核心表：
1. **study_words** - 用户学习进度（当前状态）
2. **study_logs** - 学习日志（历史记录）

## 表关系

```
User (1) ──< (N) study_words ──> (1) Word
     (1) ──< (N) study_logs ──> (1) Word
```

## 两表对比

| 特性 | study_words | study_logs |
|------|-------------|------------|
| **用途** | 记录当前学习状态 | 记录历史学习事件 |
| **数据量** | 每个用户每个单词一条 | 每次学习/复习一条 |
| **更新频率** | 每次学习时更新 | 每次学习时新增 |
| **主要字段** | 状态、SRS参数、时间戳 | 事件类型、评分、时长、快照 |
| **查询场景** | 获取待复习单词、学习进度 | 学习历史、统计分析 |
| **数据增长** | 线性增长（单词数） | 快速增长（每次学习） |

## 数据流程

### 1. 初次学习单词

```dart
// Step 1: 创建 study_words 记录
final studyWord = StudyWord(
  userId: 1,
  wordId: 100,
  userState: UserWordState.learning,
  interval: 1.0,
  easeFactor: 2.5,
  nextReviewAt: DateTime.now().add(Duration(days: 1)),
  // ...
);
await studyWordRepository.createStudyWord(studyWord);

// Step 2: 记录到 study_logs
await studyLogRepository.logFirstLearn(
  userId: 1,
  wordId: 100,
  durationMs: 8000,
  intervalAfter: 1.0,
  easeFactorAfter: 2.5,
  nextReviewAtAfter: DateTime.now().add(Duration(days: 1)),
);
```

### 2. 复习单词

```dart
// Step 1: 计算 SRS 参数
final srsResult = SRSCalculator.calculateNextReview(
  currentInterval: studyWord.interval,
  currentEaseFactor: studyWord.easeFactor,
  isCorrect: true,
  quality: 4,
);

// Step 2: 更新 study_words
await studyWordRepository.recordCorrectReview(
  userId,
  wordId,
  newInterval: srsResult['interval']!,
  newEaseFactor: srsResult['easeFactor']!,
);

// Step 3: 记录到 study_logs
await studyLogRepository.logReview(
  userId: userId,
  wordId: wordId,
  rating: ReviewRating.easy,
  durationMs: 5000,
  intervalAfter: srsResult['interval']!,
  easeFactorAfter: srsResult['easeFactor']!,
  nextReviewAtAfter: DateTime.now().add(
    Duration(days: srsResult['interval']!.ceil()),
  ),
);
```

### 3. 标记已掌握

```dart
// Step 1: 更新 study_words
await studyWordRepository.markAsMastered(userId, wordId);

// Step 2: 记录到 study_logs
await studyLogRepository.logMarkMastered(userId: userId, wordId: wordId);
```

## 已创建的文件

### 数据模型
- ✅ `lib/data/models/study_word.dart` - StudyWord 模型
- ✅ `lib/data/models/study_log.dart` - StudyLog 模型

### 数据仓库
- ✅ `lib/data/repositories/study_word_repository.dart` - 学习进度仓库
- ✅ `lib/data/repositories/study_word_repository_provider.dart` - Provider
- ✅ `lib/data/repositories/study_log_repository.dart` - 学习日志仓库
- ✅ `lib/data/repositories/study_log_repository_provider.dart` - Provider

### 文档
- ✅ `.kiro/steering/database.md` - 数据库架构文档（已更新）
- ✅ `STUDY_PROGRESS_SETUP.md` - 学习进度使用指南
- ✅ `STUDY_LOGS_SETUP.md` - 学习日志使用指南
- ✅ `STUDY_TABLES_SUMMARY.md` - 本文档

## 核心功能

### StudyWord (学习进度)

**状态管理**:
- 未学习 (newWord)
- 学习中 (learning)
- 已掌握 (mastered)
- 已忽略 (ignored)

**SRS 参数**:
- interval: 复习间隔（天）
- easeFactor: 难度因子
- streak: 连续答对次数
- totalReviews: 累计复习次数
- failCount: 答错次数

**主要方法**:
```dart
// 查询
getStudyWord(userId, wordId)
getUserStudyWords(userId)
getDueReviews(userId)
getNewWords(userId)
getUserStatistics(userId)

// 更新
recordCorrectReview(userId, wordId, ...)
recordIncorrectReview(userId, wordId, ...)
markAsMastered(userId, wordId)
markAsIgnored(userId, wordId)
resetProgress(userId, wordId)
```

### StudyLog (学习日志)

**事件类型**:
- 初次学习 (firstLearn)
- 复习 (review)
- 标记已掌握 (markMastered)
- 标记忽略 (markIgnored)
- 重置进度 (reset)
- 自动计划 (autoSchedule)

**复习评分**:
- Again (1): 完全忘记
- Hard (2): 困难
- Good (3): 一般
- Easy (4): 简单

**主要方法**:
```dart
// 记录
logFirstLearn(userId, wordId, ...)
logReview(userId, wordId, rating, ...)
logMarkMastered(userId, wordId)
logMarkIgnored(userId, wordId)
logReset(userId, wordId)

// 查询
getUserLogs(userId)
getWordLogs(userId, wordId)
getLogsByType(userId, logType)
getLogsByDateRange(userId, startDate, endDate)

// 统计
getDailyStatistics(userId, days)
getRatingDistribution(userId)
getTimeStatistics(userId, days)
getHeatmapData(userId, days)
getOverallStatistics(userId)
```

## 使用场景

### 1. 学习页面
```dart
// 获取今日待复习单词
final dueWords = await studyWordRepository.getDueReviews(userId, limit: 20);

// 获取新单词
final newWords = await studyWordRepository.getNewWords(userId, limit: 10);
```

### 2. 统计页面
```dart
// 学习进度概览
final stats = await studyWordRepository.getUserStatistics(userId);
print('已掌握: ${stats['mastered_words']}/${stats['total_words']}');

// 每日学习统计
final dailyStats = await studyLogRepository.getDailyStatistics(userId, days: 30);

// 复习评分分布
final distribution = await studyLogRepository.getRatingDistribution(userId);
```

### 3. 历史页面
```dart
// 学习历史
final logs = await studyLogRepository.getUserLogs(userId, limit: 50);

// 某个单词的学习轨迹
final wordLogs = await studyLogRepository.getWordLogs(userId, wordId);
```

### 4. 热力图
```dart
// 获取一年的学习数据
final heatmap = await studyLogRepository.getHeatmapData(userId, days: 365);
// 结果: {'2024-01-15': 10, '2024-01-16': 5, ...}
```

## 性能优化

### 索引建议

```sql
-- study_words 索引
CREATE INDEX idx_study_words_user_id ON study_words(user_id);
CREATE INDEX idx_study_words_user_state ON study_words(user_id, user_state);
CREATE INDEX idx_study_words_next_review ON study_words(user_id, next_review_at);

-- study_logs 索引
CREATE INDEX idx_study_logs_user_id ON study_logs(user_id);
CREATE INDEX idx_study_logs_word_id ON study_logs(word_id);
CREATE INDEX idx_study_logs_created_at ON study_logs(created_at);
CREATE INDEX idx_study_logs_user_created ON study_logs(user_id, created_at);
CREATE INDEX idx_study_logs_user_word ON study_logs(user_id, word_id);
```

### 查询优化

1. **分页**: 使用 `limit` 和 `offset`
2. **缓存**: 缓存统计结果
3. **批量操作**: 使用 batch 操作
4. **定期清理**: 删除旧日志（90天前）

## 数据维护

### 定期清理日志

```dart
// 每月清理一次，保留最近90天
final cutoffDate = DateTime.now().subtract(Duration(days: 90));
await studyLogRepository.deleteLogsBeforeDate(cutoffDate);
```

### 数据备份

```dart
// 导出用户学习数据
final studyWords = await studyWordRepository.getUserStudyWords(userId);
final logs = await studyLogRepository.getUserLogs(userId);

// 序列化为 JSON
final backup = {
  'study_words': studyWords.map((w) => w.toMap()).toList(),
  'study_logs': logs.map((l) => l.toMap()).toList(),
};
```

## 注意事项

1. **数据一致性**: 更新 study_words 时必须同时记录 study_logs
2. **时间戳**: 数据库使用秒，Dart 使用毫秒，需要转换
3. **日志增长**: study_logs 会快速增长，需要定期清理
4. **唯一约束**: study_words 的 (user_id, word_id) 必须唯一
5. **评分验证**: rating 仅用于 log_type = 2（复习）

## 下一步开发

### 短期
1. ✅ 数据模型和 Repository
2. ⏳ 创建 SRS 算法服务
3. ⏳ 实现学习 Controller
4. ⏳ 实现复习 Controller

### 中期
1. ⏳ 学习进度页面
2. ⏳ 统计图表页面
3. ⏳ 学习历史页面
4. ⏳ 学习热力图

### 长期
1. ⏳ 学习提醒功能
2. ⏳ 学习目标设置
3. ⏳ 学习报告导出
4. ⏳ 数据同步（多设备）

## 总结

学习系统的数据层已经完成：
- **study_words**: 管理当前学习状态，支持 SRS 算法
- **study_logs**: 记录学习历史，支持统计分析

两表配合使用，既能高效查询当前状态，又能详细追踪学习轨迹，为后续的学习功能开发提供了坚实的数据基础。
