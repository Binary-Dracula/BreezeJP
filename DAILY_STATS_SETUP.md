# 每日统计功能说明

## 概述

`daily_stats` 表用于汇总用户每天的学习数据，提供快速的报表查询和趋势分析，无需实时聚合 `study_logs`。

## 数据库表结构

### daily_stats

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 主键 |
| user_id | INTEGER | 用户 ID |
| date | TEXT | 日期（YYYY-MM-DD） |
| total_study_time | INTEGER | 当天学习总时长（秒） |
| learned_words_count | INTEGER | 当天新学单词数量 |
| reviewed_words_count | INTEGER | 当天复习单词数量 |
| mastered_words_count | INTEGER | 当天手动标记掌握数量 |
| failed_count | INTEGER | 当天错误次数 |
| created_at | INTEGER | 创建时间（Unix 时间戳） |
| updated_at | INTEGER | 更新时间（Unix 时间戳） |

**唯一约束**: `(user_id, date)` - 每个用户每天只有一条记录

## 数据模型

### DailyStat

```dart
class DailyStat {
  final int id;
  final int userId;
  final DateTime date;
  final int totalStudyTime;        // 秒
  final int learnedWordsCount;
  final int reviewedWordsCount;
  final int masteredWordsCount;
  final int failedCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 辅助属性
  String get dateString;           // YYYY-MM-DD
  double get totalStudyMinutes;    // 分钟
  double get totalStudyHours;      // 小时
  int get totalWordsCount;         // 总单词数
  bool get hasActivity;            // 是否有学习活动
  double? get accuracy;            // 正确率 (0.0-1.0)
  String get accuracyPercentage;   // 正确率百分比
  double? get avgTimePerWord;      // 平均每个单词时间
  StudyEfficiency get efficiency;  // 学习效率评级
}
```

### StudyEfficiency 枚举

```dart
enum StudyEfficiency {
  none,    // 无活动
  low,     // 低效
  medium,  // 中等
  high,    // 高效
}
```

## Repository 使用

### 基础操作

```dart
final repository = ref.read(dailyStatRepositoryProvider);

// 获取指定日期的统计
final stat = await repository.getDailyStat(userId, DateTime.now());

// 获取或创建今日统计
final todayStat = await repository.getOrCreateTodayStat(userId);

// 创建统计
final newStat = DailyStat.createToday(userId);
await repository.createDailyStat(newStat);

// 更新统计
await repository.updateDailyStat(updatedStat);
```

### 查询方法

```dart
// 获取用户所有统计
final allStats = await repository.getUserDailyStats(userId);

// 获取日期范围内的统计
final stats = await repository.getDailyStatsByDateRange(
  userId,
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 31),
);

// 获取最近 30 天的统计
final recentStats = await repository.getRecentDailyStats(userId, days: 30);
```

### 增量更新方法

```dart
// 增加学习时长（秒）
await repository.incrementStudyTime(userId, DateTime.now(), 300);

// 增加新学单词数
await repository.incrementLearnedWords(userId, DateTime.now(), count: 1);

// 增加复习单词数
await repository.incrementReviewedWords(userId, DateTime.now(), count: 1);

// 增加掌握单词数
await repository.incrementMasteredWords(userId, DateTime.now(), count: 1);

// 增加错误次数
await repository.incrementFailedCount(userId, DateTime.now(), count: 1);
```

### 统计方法

```dart
// 获取本周统计汇总
final weeklySummary = await repository.getWeeklySummary(userId);
print('本周学习时长: ${weeklySummary['total_time']}秒');
print('本周新学单词: ${weeklySummary['total_learned']}');
print('本周复习单词: ${weeklySummary['total_reviewed']}');
print('活跃天数: ${weeklySummary['active_days']}');

// 获取本月统计汇总
final monthlySummary = await repository.getMonthlySummary(userId);

// 计算学习连续天数
final streak = await repository.calculateStreak(userId);
print('连续学习 $streak 天');

// 获取热力图数据
final heatmap = await repository.getHeatmapData(userId, days: 365);
// 结果: {'2024-01-15': 10, '2024-01-16': 5, ...}
```

## 与其他表配合使用

### 完整的学习流程

```dart
// 1. 用户完成学习/复习
final startTime = DateTime.now();
// ... 学习过程 ...
final endTime = DateTime.now();
final durationMs = endTime.difference(startTime).inMilliseconds;
final durationSeconds = durationMs ~/ 1000;

// 2. 更新 study_words
await studyWordRepository.recordCorrectReview(userId, wordId, ...);

// 3. 记录到 study_logs
await studyLogRepository.logReview(
  userId: userId,
  wordId: wordId,
  rating: ReviewRating.good,
  durationMs: durationMs,
  ...
);

// 4. 更新 daily_stats（实时更新）
final today = DateTime.now();
await dailyStatRepository.incrementStudyTime(userId, today, durationSeconds);
await dailyStatRepository.incrementReviewedWords(userId, today);

// 如果答错了
if (rating == ReviewRating.again) {
  await dailyStatRepository.incrementFailedCount(userId, today);
}
```

### 批量更新（定时任务方式）

```dart
// 每天凌晨汇总前一天的数据
Future<void> aggregateDailyStats(int userId, DateTime date) async {
  // 从 study_logs 聚合数据
  final logs = await studyLogRepository.getLogsByDateRange(
    userId,
    startDate: date,
    endDate: date,
  );

  int totalTime = 0;
  int learnedCount = 0;
  int reviewedCount = 0;
  int masteredCount = 0;
  int failedCount = 0;

  for (final log in logs) {
    totalTime += log.durationMs ~/ 1000;
    
    switch (log.logType) {
      case LogType.firstLearn:
        learnedCount++;
        break;
      case LogType.review:
        reviewedCount++;
        if (log.rating == ReviewRating.again) {
          failedCount++;
        }
        break;
      case LogType.markMastered:
        masteredCount++;
        break;
      default:
        break;
    }
  }

  // 创建或更新 daily_stats
  final existingStat = await dailyStatRepository.getDailyStat(userId, date);
  
  if (existingStat == null) {
    final newStat = DailyStat.createForDate(userId, date).copyWith(
      totalStudyTime: totalTime,
      learnedWordsCount: learnedCount,
      reviewedWordsCount: reviewedCount,
      masteredWordsCount: masteredCount,
      failedCount: failedCount,
    );
    await dailyStatRepository.createDailyStat(newStat);
  } else {
    final updated = existingStat.copyWith(
      totalStudyTime: totalTime,
      learnedWordsCount: learnedCount,
      reviewedWordsCount: reviewedCount,
      masteredWordsCount: masteredCount,
      failedCount: failedCount,
      updatedAt: DateTime.now(),
    );
    await dailyStatRepository.updateDailyStat(updated);
  }
}
```

## UI 集成示例

### 学习日历

```dart
class StudyCalendarWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(dailyStatRepositoryProvider);
    
    return FutureBuilder<List<DailyStat>>(
      future: repository.getRecentDailyStats(userId, days: 30),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 30,
          itemBuilder: (context, index) {
            final date = DateTime.now().subtract(Duration(days: 29 - index));
            final stat = stats.firstWhere(
              (s) => s.dateString == _formatDate(date),
              orElse: () => DailyStat.createForDate(userId, date),
            );
            
            return Container(
              decoration: BoxDecoration(
                color: _getColorForActivity(stat.totalWordsCount),
                border: Border.all(color: Colors.grey),
              ),
              child: Center(
                child: Text('${date.day}'),
              ),
            );
          },
        );
      },
    );
  }
  
  Color _getColorForActivity(int count) {
    if (count == 0) return Colors.grey[200]!;
    if (count < 10) return Colors.green[200]!;
    if (count < 20) return Colors.green[400]!;
    return Colors.green[600]!;
  }
}
```

### 学习统计卡片

```dart
class StudyStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(dailyStatRepositoryProvider);
    
    return FutureBuilder<Map<String, dynamic>>(
      future: repository.getWeeklySummary(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final summary = snapshot.data!;
        final totalTime = summary['total_time'] as int? ?? 0;
        final totalLearned = summary['total_learned'] as int? ?? 0;
        final totalReviewed = summary['total_reviewed'] as int? ?? 0;
        final activeDays = summary['active_days'] as int? ?? 0;
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本周学习', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 16),
                _buildStatRow('学习时长', '${totalTime ~/ 60} 分钟'),
                _buildStatRow('新学单词', '$totalLearned 个'),
                _buildStatRow('复习单词', '$totalReviewed 个'),
                _buildStatRow('活跃天数', '$activeDays 天'),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
```

### 连续学习天数

```dart
class StreakWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(dailyStatRepositoryProvider);
    
    return FutureBuilder<int>(
      future: repository.calculateStreak(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final streak = snapshot.data!;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.local_fire_department, size: 48, color: Colors.orange),
                SizedBox(height: 8),
                Text(
                  '$streak',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text('连续学习天数'),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## 更新策略

### 策略 1: 实时更新（推荐）

每次学习/复习后立即更新 daily_stats：

**优点**:
- 数据实时性强
- 用户立即看到更新
- 无需额外定时任务

**缺点**:
- 每次学习都要写数据库
- 可能有并发问题

### 策略 2: 定时聚合

每天凌晨从 study_logs 聚合数据：

**优点**:
- 减少数据库写入
- 数据一致性好
- 可以修正错误数据

**缺点**:
- 当天数据不实时
- 需要定时任务

### 策略 3: 混合模式（最佳）

- 实时更新当天数据
- 定时任务修正历史数据

## 性能优化

### 索引建议

```sql
-- 用户查询索引
CREATE INDEX idx_daily_stats_user_id ON daily_stats(user_id);

-- 日期查询索引
CREATE INDEX idx_daily_stats_date ON daily_stats(date);

-- 复合索引（用户+日期）
CREATE INDEX idx_daily_stats_user_date ON daily_stats(user_id, date);
```

### 查询优化

1. **使用日期范围**: 避免查询所有历史数据
2. **分页**: 使用 limit 和 offset
3. **缓存**: 缓存本周/本月统计
4. **批量操作**: 使用 batch 更新

## 数据维护

### 定期清理

```dart
// 删除一年前的数据
final cutoffDate = DateTime.now().subtract(Duration(days: 365));
await repository.deleteStatsBeforeDate(cutoffDate);
```

### 数据修正

```dart
// 重新聚合某一天的数据
await aggregateDailyStats(userId, DateTime(2024, 1, 15));
```

## 注意事项

1. **唯一约束**: (user_id, date) 必须唯一
2. **日期格式**: 使用 YYYY-MM-DD 格式
3. **时区**: 注意时区问题，建议使用本地时间
4. **并发**: 使用 INSERT OR REPLACE 或事务处理并发
5. **数据一致性**: 定期校验 daily_stats 与 study_logs 的一致性

## 相关文件

- `.kiro/steering/database.md` - 数据库文档
- `lib/data/models/daily_stat.dart` - 数据模型
- `lib/data/repositories/daily_stat_repository.dart` - 数据仓库
- `lib/data/repositories/daily_stat_repository_provider.dart` - Provider
- `DAILY_STATS_SETUP.md` - 本文档

## 下一步

1. 实现学习日历页面
2. 创建统计图表（折线图、柱状图）
3. 实现学习热力图
4. 添加学习目标设置
5. 实现学习提醒功能
