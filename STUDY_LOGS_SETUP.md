# 学习日志功能说明

## 概述

`study_logs` 表用于记录用户的所有学习事件和历史，用于分析学习效果、生成统计报告和追踪学习轨迹。

## 数据库表结构

### study_logs

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 主键 |
| user_id | INTEGER | 用户 ID |
| word_id | INTEGER | 单词 ID |
| log_type | INTEGER | 事件类型（1-6） |
| rating | INTEGER | 复习评分（1-4，仅复习事件） |
| interval_after | REAL | 操作后的间隔（天） |
| ease_factor_after | REAL | 操作后的难度因子 |
| next_review_at_after | INTEGER | 操作后的下次复习时间戳 |
| duration_ms | INTEGER | 学习/复习花费时间（毫秒） |
| created_at | INTEGER | 创建时间（Unix 时间戳） |

## 数据模型

### StudyLog

```dart
class StudyLog {
  final int id;
  final int userId;
  final int wordId;
  final LogType logType;
  final ReviewRating? rating;
  final double? intervalAfter;
  final double? easeFactorAfter;
  final DateTime? nextReviewAtAfter;
  final int durationMs;
  final DateTime createdAt;
  
  // 辅助方法
  bool get isReview;           // 是否为复习事件
  bool get isFirstLearn;       // 是否为初次学习
  double get durationSeconds;  // 学习时长（秒）
  double get durationMinutes;  // 学习时长（分钟）
}
```

### LogType 枚举

```dart
enum LogType {
  firstLearn(1),    // 初次学习
  review(2),        // 复习
  markMastered(3),  // 标记已掌握
  markIgnored(4),   // 标记忽略
  reset(5),         // 重置进度
  autoSchedule(6),  // 自动计划（可选）
}
```

### ReviewRating 枚举

```dart
enum ReviewRating {
  again(1),  // 完全忘记
  hard(2),   // 困难
  good(3),   // 一般
  easy(4),   // 简单
}
```

## Repository 使用

### 基础操作

```dart
final repository = ref.read(studyLogRepositoryProvider);

// 创建日志
final log = StudyLog(
  id: 0,
  userId: 1,
  wordId: 100,
  logType: LogType.review,
  rating: ReviewRating.good,
  durationMs: 5000,
  intervalAfter: 2.5,
  easeFactorAfter: 2.6,
  nextReviewAtAfter: DateTime.now().add(Duration(days: 3)),
  createdAt: DateTime.now(),
);
await repository.createLog(log);
```

### 便捷方法

```dart
// 记录初次学习
await repository.logFirstLearn(
  userId: 1,
  wordId: 100,
  durationMs: 8000,
  intervalAfter: 1.0,
  easeFactorAfter: 2.5,
  nextReviewAtAfter: DateTime.now().add(Duration(days: 1)),
);

// 记录复习
await repository.logReview(
  userId: 1,
  wordId: 100,
  rating: ReviewRating.good,
  durationMs: 5000,
  intervalAfter: 2.5,
  easeFactorAfter: 2.6,
  nextReviewAtAfter: DateTime.now().add(Duration(days: 3)),
);

// 记录标记已掌握
await repository.logMarkMastered(userId: 1, wordId: 100);

// 记录标记忽略
await repository.logMarkIgnored(userId: 1, wordId: 100);

// 记录重置进度
await repository.logReset(userId: 1, wordId: 100);
```

### 查询方法

```dart
// 获取用户学习历史
final logs = await repository.getUserLogs(userId, limit: 50);

// 获取某个单词的学习历史
final wordLogs = await repository.getWordLogs(userId, wordId);

// 获取特定类型的日志
final reviewLogs = await repository.getLogsByType(
  userId,
  LogType.review,
  limit: 100,
);

// 获取日期范围内的日志
final logs = await repository.getLogsByDateRange(
  userId,
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);
```

### 统计方法

```dart
// 获取每日学习统计（最近30天）
final dailyStats = await repository.getDailyStatistics(userId, days: 30);
for (final stat in dailyStats) {
  print('日期: ${stat['date']}');
  print('总复习: ${stat['total_reviews']}');
  print('新学习: ${stat['new_learned']}');
  print('复习数: ${stat['reviews']}');
  print('总时长: ${stat['total_duration_ms']}ms');
}

// 获取复习评分分布
final distribution = await repository.getRatingDistribution(userId);
print('Again: ${distribution[ReviewRating.again] ?? 0}');
print('Hard: ${distribution[ReviewRating.hard] ?? 0}');
print('Good: ${distribution[ReviewRating.good] ?? 0}');
print('Easy: ${distribution[ReviewRating.easy] ?? 0}');

// 获取学习时长统计（最近7天）
final timeStats = await repository.getTimeStatistics(userId, days: 7);
print('总时长: ${timeStats['total_ms']}ms');
print('平均时长: ${timeStats['avg_ms']}ms');
print('学习次数: ${timeStats['total_sessions']}');

// 获取热力图数据（用于日历视图）
final heatmap = await repository.getHeatmapData(userId, days: 365);
// heatmap: {'2024-01-15': 10, '2024-01-16': 5, ...}

// 获取总体统计
final overall = await repository.getOverallStatistics(userId);
print('总日志数: ${overall['total_logs']}');
print('学习单词数: ${overall['unique_words']}');
print('初次学习: ${overall['first_learns']}');
print('复习次数: ${overall['reviews']}');
```

## 与 StudyWord 配合使用

### 完整的学习流程

```dart
// 1. 用户答题
final startTime = DateTime.now();
// ... 用户学习/复习单词 ...
final endTime = DateTime.now();
final durationMs = endTime.difference(startTime).inMilliseconds;

// 2. 计算 SRS 参数
final srsResult = SRSCalculator.calculateNextReview(
  currentInterval: studyWord.interval,
  currentEaseFactor: studyWord.easeFactor,
  isCorrect: rating.isCorrect,
  quality: rating.value,
);

// 3. 更新 study_words
if (rating.isCorrect) {
  await studyWordRepository.recordCorrectReview(
    userId,
    wordId,
    newInterval: srsResult['interval']!,
    newEaseFactor: srsResult['easeFactor']!,
  );
} else {
  await studyWordRepository.recordIncorrectReview(
    userId,
    wordId,
    newInterval: srsResult['interval']!,
    newEaseFactor: srsResult['easeFactor']!,
  );
}

// 4. 记录日志到 study_logs
await studyLogRepository.logReview(
  userId: userId,
  wordId: wordId,
  rating: rating,
  durationMs: durationMs,
  intervalAfter: srsResult['interval']!,
  easeFactorAfter: srsResult['easeFactor']!,
  nextReviewAtAfter: DateTime.now().add(
    Duration(days: srsResult['interval']!.ceil()),
  ),
);
```

## UI 集成示例

### 学习历史列表

```dart
class StudyHistoryPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(studyLogRepositoryProvider);
    
    return FutureBuilder<List<StudyLog>>(
      future: repository.getUserLogs(userId, limit: 50),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final logs = snapshot.data!;
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              leading: Icon(_getIconForLogType(log.logType)),
              title: Text('单词 ID: ${log.wordId}'),
              subtitle: Text(
                '${log.logType.description} - '
                '${log.createdAt.toString().substring(0, 16)}',
              ),
              trailing: log.rating != null
                  ? Chip(
                      label: Text(log.rating!.description),
                      backgroundColor: Color(
                        int.parse(log.rating!.colorHex.substring(1), radix: 16) + 0xFF000000,
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
```

### 学习统计图表

```dart
class StudyStatisticsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(studyLogRepositoryProvider);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repository.getDailyStatistics(userId, days: 7),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        return Column(
          children: stats.map((stat) {
            return Card(
              child: ListTile(
                title: Text(stat['date'] as String),
                subtitle: Text(
                  '学习: ${stat['new_learned']} | '
                  '复习: ${stat['reviews']} | '
                  '时长: ${(stat['total_duration_ms'] as int) ~/ 1000}秒',
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

### 学习热力图

```dart
class StudyHeatmapWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(studyLogRepositoryProvider);
    
    return FutureBuilder<Map<String, int>>(
      future: repository.getHeatmapData(userId, days: 90),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final heatmap = snapshot.data!;
        // 使用 fl_chart 或其他图表库绘制热力图
        return Container(
          // 热力图实现...
        );
      },
    );
  }
}
```

## 数据清理

```dart
// 删除90天前的旧日志（节省空间）
final cutoffDate = DateTime.now().subtract(Duration(days: 90));
final deletedCount = await repository.deleteLogsBeforeDate(cutoffDate);
print('删除了 $deletedCount 条旧日志');

// 删除用户的所有日志（用户注销时）
await repository.deleteUserLogs(userId);
```

## 性能优化建议

1. **分页查询**: 使用 `limit` 和 `offset` 避免一次加载过多数据
2. **索引优化**: 在 `user_id`, `word_id`, `created_at` 上创建索引
3. **定期清理**: 定期删除旧日志，保持数据库体积
4. **批量插入**: 使用 `createLogs()` 批量创建日志
5. **缓存统计**: 将统计结果缓存到内存，避免频繁查询

## 索引建议

```sql
-- 用户查询索引
CREATE INDEX idx_study_logs_user_id ON study_logs(user_id);

-- 单词查询索引
CREATE INDEX idx_study_logs_word_id ON study_logs(word_id);

-- 时间范围查询索引
CREATE INDEX idx_study_logs_created_at ON study_logs(created_at);

-- 复合索引（用户+时间）
CREATE INDEX idx_study_logs_user_created ON study_logs(user_id, created_at);

-- 复合索引（用户+单词）
CREATE INDEX idx_study_logs_user_word ON study_logs(user_id, word_id);
```

## 注意事项

1. **日志量**: 日志会随时间快速增长，需要定期清理
2. **隐私**: 日志包含详细的学习行为，注意数据隐私
3. **时间戳**: 使用 Unix 时间戳（秒），与 Dart 毫秒需要转换
4. **评分**: `rating` 仅用于复习事件（log_type = 2）
5. **快照**: `*_after` 字段记录操作后的状态，用于追踪算法变化

## 相关文件

- `.kiro/steering/database.md` - 数据库文档
- `lib/data/models/study_log.dart` - 数据模型
- `lib/data/repositories/study_log_repository.dart` - 数据仓库
- `lib/data/repositories/study_log_repository_provider.dart` - Provider
- `STUDY_LOGS_SETUP.md` - 本文档

## 下一步

1. 实现学习历史页面
2. 创建学习统计图表
3. 实现学习热力图
4. 添加学习报告导出功能
5. 实现学习提醒和目标设置
